import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../crypto/crypto_engine.dart';
import '../config/constants.dart';
import '../../data/models/vault_entry.dart';

class AppState extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _initialized = false;
  bool _authenticated = false;
  bool _hasMasterPassword = false;
  bool _useBiometrics = false;
  bool _fingerprintAvailable = false;
  bool _fingerprintHardwarePresent = false;
  int _activeTab = 0;
  int _securityScore = 0;
  List<VaultEntry> _vault = [];
  List<AuditEvent> _auditLog = [];
  String _searchQuery = '';
  VaultItemCategory? _filterCategory;
  Timer? _inactivityTimer;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  String? _lastBiometricError;
  String _fullName = '';
  String _country = '';
  String _preferredLanguage = 'en';
  bool _profileComplete = false;

  // Cached vault key – cleared on lock, populated after password auth.
  // This avoids re-running PBKDF2 on every vault operation.
  Uint8List? _cachedKey;

  final LocalAuthentication _localAuth = LocalAuthentication();

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get initialized => _initialized;
  bool get authenticated => _authenticated;
  bool get hasMasterPassword => _hasMasterPassword;
  bool get useBiometrics => _useBiometrics;
  bool get fingerprintAvailable => _fingerprintAvailable;
  bool get fingerprintHardwarePresent => _fingerprintHardwarePresent;
  int get activeTab => _activeTab;
  int get securityScore => _securityScore;
  List<VaultEntry> get vault => _vault;
  List<AuditEvent> get auditLog => _auditLog;
  String get searchQuery => _searchQuery;
  VaultItemCategory? get filterCategory => _filterCategory;
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  int get failedAttempts => _failedAttempts;
  String? get lastBiometricError => _lastBiometricError;
  String get fullName => _fullName;
  String get country => _country;
  String get preferredLanguage => _preferredLanguage;
  bool get profileComplete => _profileComplete;

  String tr(String key) {
    final strings = kLangStrings[_preferredLanguage] ?? kLangStrings['en']!;
    return strings[key] ?? kLangStrings['en']![key] ?? key;
  }

  // ── Profile ────────────────────────────────────────────────────────────────
  Future<void> saveUserProfile(
      String name, String country, String lang) async {
    _fullName = name;
    _country = country;
    _preferredLanguage = lang;
    _profileComplete = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_full_name', name);
      await prefs.setString('user_country', country);
      await prefs.setString('user_language', lang);
      await prefs.setBool('profile_complete', true);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> updateLanguage(String lang) async {
    _preferredLanguage = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_language', lang);
    } catch (_) {}
    notifyListeners();
  }

  // ── Vault filtering ────────────────────────────────────────────────────────
  List<VaultEntry> get filteredVault {
    var list = _vault.where((e) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.username.toLowerCase().contains(q) ||
          (e.website?.toLowerCase().contains(q) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(q));
      final matchesCategory =
          _filterCategory == null || e.category == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList();
    list.sort((a, b) {
      if (a.isFavorite && !b.isFavorite) return -1;
      if (!a.isFavorite && b.isFavorite) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Map<VaultItemCategory, int> get categoryBreakdown {
    final map = <VaultItemCategory, int>{};
    for (final e in _vault) {
      map[e.category] = (map[e.category] ?? 0) + 1;
    }
    return map;
  }

  int get weakPasswordCount => _vault
      .where((e) =>
          e.category == VaultItemCategory.login && e.strengthScore < 50)
      .length;

  int get duplicatePasswordCount {
    final secrets = <String>[];
    for (final e in _vault) {
      if (e.encryptedSecret.isNotEmpty) secrets.add(e.encryptedSecret);
    }
    return secrets.length - secrets.toSet().length;
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setFilterCategory(VaultItemCategory? cat) {
    _filterCategory = cat;
    notifyListeners();
  }

  // ── Initialisation ─────────────────────────────────────────────────────────
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hasMasterPassword = prefs.getBool('has_master_password') ?? false;
      _useBiometrics = prefs.getBool('use_biometrics') ?? false;
      _profileComplete = prefs.getBool('profile_complete') ?? false;
      _fullName = prefs.getString('user_full_name') ?? '';
      _country = prefs.getString('user_country') ?? '';
      _preferredLanguage = prefs.getString('user_language') ?? 'en';
    } catch (_) {
      _preferredLanguage = 'en';
    }

    await _checkFingerprintAvailability();

    // If user had biometrics enabled but hardware is now unavailable, keep
    // the preference so password still works; just flip off the hw flag.
    if (_useBiometrics && !_fingerprintAvailable) {
      _useBiometrics = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_biometrics', false);
      } catch (_) {}
    }

    try {
      await _loadVault();
    } catch (_) {
      _vault = [];
    }

    try {
      await _loadAuditLog();
    } catch (_) {
      _auditLog = [];
    }

    _computeSecurityScore();
    _initialized = true;
    notifyListeners();
  }

  // ── Biometric availability (fingerprint-only, MIUI-safe) ──────────────────
  Future<void> _checkFingerprintAvailability() async {
    try {
      // isDeviceSupported: true when the device has biometric/pin hardware.
      // This does NOT require a fingerprint to be enrolled.
      final isSupported = await _localAuth.isDeviceSupported();
      _fingerprintHardwarePresent = isSupported;

      if (!isSupported) {
        _fingerprintAvailable = false;
        return;
      }

      // canCheckBiometrics: true when hardware exists AND at least one
      // biometric is enrolled. On MIUI this sometimes returns false even
      // when a fingerprint is enrolled, so we also check getAvailableBiometrics.
      bool canCheck = false;
      try {
        canCheck = await _localAuth.canCheckBiometrics;
      } on PlatformException {
        // MIUI can throw here — fall through to getAvailableBiometrics below.
      }

      // getAvailableBiometrics: returns enrolled types.
      // BiometricType.strong covers hardware fingerprint on Android 9+.
      // BiometricType.fingerprint covers older APIs and some OEMs.
      // We accept either. We never check for .face or .iris.
      List<BiometricType> enrolled = [];
      try {
        enrolled = await _localAuth.getAvailableBiometrics();
      } on PlatformException {
        enrolled = [];
      }

      final hasFingerprint =
          enrolled.contains(BiometricType.fingerprint) ||
          enrolled.contains(BiometricType.strong);

      // Device has hardware (so setup is possible) even if not yet enrolled.
      _fingerprintHardwarePresent = isSupported;
      // "Available" = can actually authenticate right now (enrolled).
      _fingerprintAvailable = canCheck || hasFingerprint;
    } on PlatformException {
      _fingerprintHardwarePresent = false;
      _fingerprintAvailable = false;
    } catch (_) {
      _fingerprintHardwarePresent = false;
      _fingerprintAvailable = false;
    }
  }

  // ── Setup master password ──────────────────────────────────────────────────
  Future<void> setupMasterPassword(String password) async {
    final salt = CryptoEngine.generateSalt();
    final hash = CryptoEngine.hashPassword(password, salt);
    await CryptoEngine.storeSecure('master_salt', base64.encode(salt));
    await CryptoEngine.storeSecure('master_hash', hash);

    // Derive and cache the vault key immediately.
    final newKey = CryptoEngine.deriveKeyFromPassword(password, salt);

    if (_vault.isNotEmpty && _cachedKey != null) {
      await _reEncryptVault(_cachedKey!, newKey);
    }

    _cachedKey = newKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_master_password', true);
    } catch (_) {}

    _hasMasterPassword = true;
    _authenticated = true;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _addAuditEvent('AUTH', 'Master password configured');
    _computeSecurityScore();
    _resetInactivityTimer();
    notifyListeners();
  }

  // ── Setup fingerprint ──────────────────────────────────────────────────────
  Future<bool> setupFingerprint() async {
    _lastBiometricError = null;
    await _checkFingerprintAvailability();

    if (!_fingerprintHardwarePresent) {
      _lastBiometricError =
          'This device does not have fingerprint hardware.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _localAuth.authenticate(
        localizedReason:
            'Scan your fingerprint to register it with CipherGuard',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );

      if (success) {
        // Generate a biometric-bound random key for vault access when no
        // password session key is present.
        if (await CryptoEngine.readSecure('biometric_key') == null) {
          final key = CryptoEngine.generateSalt(32);
          await CryptoEngine.storeSecure(
              'biometric_key', base64.encode(key));
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_biometrics', true);
        } catch (_) {}

        _useBiometrics = true;
        _authenticated = true;
        _failedAttempts = 0;
        _lockoutUntil = null;
        _addAuditEvent('AUTH', 'Fingerprint authentication configured');
        _computeSecurityScore();
        _resetInactivityTimer();
        notifyListeners();
        return true;
      } else {
        _lastBiometricError = 'Fingerprint registration was cancelled.';
        notifyListeners();
        return false;
      }
    } on PlatformException catch (e) {
      _lastBiometricError = _fingerprintErrorMessage(e);
      notifyListeners();
      return false;
    } catch (_) {
      _lastBiometricError =
          'Could not start fingerprint registration. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> disableFingerprint() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_biometrics', false);
    } catch (_) {}
    _useBiometrics = false;
    _addAuditEvent('AUTH', 'Fingerprint authentication disabled');
    _computeSecurityScore();
    notifyListeners();
  }

  Future<void> removeMasterPassword() async {
    await CryptoEngine.deleteSecure('master_salt');
    await CryptoEngine.deleteSecure('master_hash');
    _cachedKey = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_master_password', false);
    } catch (_) {}
    _hasMasterPassword = false;
    _addAuditEvent('AUTH', 'Master password removed');
    _computeSecurityScore();
    notifyListeners();
  }

  // ── Authentication ─────────────────────────────────────────────────────────
  Future<bool> authenticateWithPassword(String password) async {
    if (isLockedOut) return false;

    try {
      final saltStr = await CryptoEngine.readSecure('master_salt');
      final hash = await CryptoEngine.readSecure('master_hash');
      if (saltStr == null || hash == null) return false;

      final salt = base64.decode(saltStr);
      final valid = CryptoEngine.verifyPassword(password, salt, hash);

      if (valid) {
        // Derive and cache vault key on successful login.
        _cachedKey = CryptoEngine.deriveKeyFromPassword(password, salt);
        _authenticated = true;
        _failedAttempts = 0;
        _lockoutUntil = null;
        _addAuditEvent('AUTH', 'Password authentication successful');
        _resetInactivityTimer();
        notifyListeners();
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil =
              DateTime.now().add(const Duration(minutes: 5));
          _addAuditEvent(
              'SECURITY', 'Account locked after failed attempts');
        }
        notifyListeners();
      }
      return valid;
    } catch (_) {
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithFingerprint() async {
    _lastBiometricError = null;

    // Re-check hardware state each time — covers "enrolled after app start".
    await _checkFingerprintAvailability();

    if (!_fingerprintAvailable) {
      _lastBiometricError =
          'No fingerprint enrolled on this device. Use your master password instead.';
      notifyListeners();
      return false;
    }

    try {
      final ok = await _localAuth.authenticate(
        localizedReason: 'Unlock your CipherGuard vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          sensitiveTransaction: true,
        ),
      );

      if (ok) {
        // Load the biometric-bound key for vault ops when no PBKDF2 key is
        // cached (i.e., the user hasn't also entered their password this
        // session).
        if (_cachedKey == null) {
          final stored =
              await CryptoEngine.readSecure('biometric_key');
          if (stored != null) {
            _cachedKey = base64.decode(stored);
          }
        }
        _authenticated = true;
        _failedAttempts = 0;
        _lockoutUntil = null;
        _addAuditEvent('AUTH', 'Fingerprint authentication successful');
        _resetInactivityTimer();
        notifyListeners();
      } else {
        _lastBiometricError = 'Fingerprint not recognised. Try again or use your password.';
        notifyListeners();
      }
      return ok;
    } on PlatformException catch (e) {
      _lastBiometricError = _fingerprintErrorMessage(e);
      notifyListeners();
      return false;
    } catch (_) {
      _lastBiometricError =
          'Fingerprint authentication failed. Use your password instead.';
      notifyListeners();
      return false;
    }
  }

  String _fingerprintErrorMessage(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
      case 'not_available':
        return 'Fingerprint hardware is not available on this device.';
      case 'NotEnrolled':
      case 'not_enrolled':
        return 'No fingerprint enrolled. Go to Settings → Security → Fingerprint.';
      case 'LockedOut':
      case 'locked_out':
        return 'Too many attempts. Fingerprint is temporarily locked. Use your password.';
      case 'PermanentlyLockedOut':
      case 'permanently_locked_out':
        return 'Fingerprint is permanently locked. Unlock the device with your PIN, then try again.';
      case 'PasscodeNotSet':
      case 'passcode_not_set':
        return 'Set up a device PIN or pattern before using fingerprint.';
      case 'otherOperatingSystem':
        return 'Fingerprint is not supported on this platform.';
      default:
        return e.message?.isNotEmpty == true
            ? e.message!
            : 'Fingerprint authentication failed. Use your password instead.';
    }
  }

  // ── Session ────────────────────────────────────────────────────────────────
  void setActiveTab(int tab) {
    _activeTab = tab;
    _resetInactivityTimer();
    notifyListeners();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () {
      _authenticated = false;
      _cachedKey = null;
      _addAuditEvent('AUTH', 'Session expired due to inactivity');
      notifyListeners();
    });
  }

  void resetTimer() => _resetInactivityTimer();

  void lock() {
    _authenticated = false;
    _cachedKey = null;
    _inactivityTimer?.cancel();
    _addAuditEvent('AUTH', 'Vault manually locked');
    notifyListeners();
  }

  // ── Key management ─────────────────────────────────────────────────────────
  Future<Uint8List> _getVaultKey() async {
    if (_cachedKey != null) return _cachedKey!;

    // Fallback: try session key stored in secure storage (legacy path).
    final stored = await CryptoEngine.readSecure('session_key');
    if (stored != null) {
      _cachedKey = base64.decode(stored);
      return _cachedKey!;
    }

    // Biometric-only path: use the biometric_key.
    final bioKey = await CryptoEngine.readSecure('biometric_key');
    if (bioKey != null) {
      _cachedKey = base64.decode(bioKey);
      return _cachedKey!;
    }

    // Emergency fallback: generate an ephemeral key (vault will be
    // unreadable after restart, but at least won't crash).
    final ephemeral = CryptoEngine.generateSalt(32);
    _cachedKey = ephemeral;
    return ephemeral;
  }

  // Keep legacy storeSessionKey for callers that still call it.
  Future<void> storeSessionKey(String password) async {
    final saltStr = await CryptoEngine.readSecure('master_salt');
    if (saltStr == null) return;
    final salt = base64.decode(saltStr);
    final key = CryptoEngine.deriveKeyFromPassword(password, salt);
    _cachedKey = key;
    await CryptoEngine.storeSecure('session_key', base64.encode(key));
  }

  Future<void> clearSessionKey() async {
    _cachedKey = null;
    await CryptoEngine.deleteSecure('session_key');
  }

  Future<void> _reEncryptVault(
      Uint8List oldKey, Uint8List newKey) async {
    for (final entry in _vault) {
      if (entry.encryptedSecret.isEmpty) continue;
      try {
        final plaintext = CryptoEngine.decryptData(
            entry.encryptedSecret, entry.iv, oldKey);
        final reEncrypted = CryptoEngine.encryptData(plaintext, newKey);
        entry.encryptedSecret = reEncrypted['ciphertext']!;
        entry.iv = reEncrypted['iv']!;
      } catch (_) {}
    }
    await _saveVault();
  }

  // ── Vault CRUD ─────────────────────────────────────────────────────────────
  Future<void> addVaultEntry(VaultEntry entry) async {
    final key = await _getVaultKey();
    final encrypted = CryptoEngine.encryptData(entry.rawSecret, key);
    entry.encryptedSecret = encrypted['ciphertext']!;
    entry.iv = encrypted['iv']!;
    entry.strengthScore = entry.category == VaultItemCategory.login
        ? CryptoEngine.analyzePasswordStrength(entry.rawSecret)
        : 100;
    entry.rawSecret = '';
    _vault.add(entry);
    await _saveVault();
    _computeSecurityScore();
    _addAuditEvent('VAULT', 'Added: ${entry.title}');
    notifyListeners();
  }

  Future<String> revealSecret(VaultEntry entry) async {
    final key = await _getVaultKey();
    return CryptoEngine.decryptData(entry.encryptedSecret, entry.iv, key);
  }

  Future<void> updateVaultEntry(VaultEntry updated) async {
    final idx = _vault.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    if (updated.rawSecret.isNotEmpty) {
      final key = await _getVaultKey();
      final encrypted =
          CryptoEngine.encryptData(updated.rawSecret, key);
      updated.encryptedSecret = encrypted['ciphertext']!;
      updated.iv = encrypted['iv']!;
      updated.strengthScore = updated.category == VaultItemCategory.login
          ? CryptoEngine.analyzePasswordStrength(updated.rawSecret)
          : 100;
      updated.rawSecret = '';
    }
    updated.updatedAt = DateTime.now();
    _vault[idx] = updated;
    await _saveVault();
    _addAuditEvent('VAULT', 'Updated: ${updated.title}');
    notifyListeners();
  }

  Future<void> deleteVaultEntry(String id) async {
    final idx = _vault.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    final title = _vault[idx].title;
    _vault.removeAt(idx);
    await _saveVault();
    _computeSecurityScore();
    _addAuditEvent('VAULT', 'Deleted: $title');
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _vault.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _vault[idx].isFavorite = !_vault[idx].isFavorite;
    await _saveVault();
    notifyListeners();
  }

  // ── Persistence ────────────────────────────────────────────────────────────
  Future<void> _saveVault() async {
    try {
      final data = _vault.map((e) => e.toJson()).toList();
      await CryptoEngine.storeSecure('vault_v2', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadVault() async {
    final raw = await CryptoEngine.readSecure('vault_v2');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _vault = list
            .map((j) => VaultEntry.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _vault = [];
      }
    }
  }

  void _addAuditEvent(String action, String detail) {
    _auditLog.insert(
        0,
        AuditEvent(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          action: action,
          detail: detail,
          timestamp: DateTime.now(),
        ));
    if (_auditLog.length > 200) {
      _auditLog = _auditLog.sublist(0, 200);
    }
    _saveAuditLog();
  }

  Future<void> _loadAuditLog() async {
    final raw = await CryptoEngine.readSecure('audit_log');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _auditLog = list
            .map((j) => AuditEvent.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _auditLog = [];
      }
    }
  }

  Future<void> _saveAuditLog() async {
    try {
      final data = _auditLog.map((e) => e.toJson()).toList();
      await CryptoEngine.storeSecure('audit_log', jsonEncode(data));
    } catch (_) {}
  }

  // ── Score ──────────────────────────────────────────────────────────────────
  void _computeSecurityScore() {
    int score = 0;
    if (_hasMasterPassword) score += 20;
    if (_useBiometrics) score += 20;
    if (_vault.isNotEmpty) score += 15;
    final weak = weakPasswordCount;
    if (weak == 0 && _vault.isNotEmpty) {
      score += 20;
    } else if (weak < 3) {
      score += 10;
    }
    final dup = duplicatePasswordCount;
    if (dup == 0 && _vault.isNotEmpty) {
      score += 15;
    } else if (dup < 2) {
      score += 7;
    }
    score += min(10, _vault.length ~/ 2);
    _securityScore = score.clamp(0, 100);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _cachedKey = null;
    super.dispose();
  }
}
