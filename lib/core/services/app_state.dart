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
  bool _initialized = false;
  bool _authenticated = false;
  bool _hasMasterPassword = false;
  bool _useBiometrics = false;
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  int _activeTab = 0;
  int _securityScore = 0;
  List<VaultEntry> _vault = [];
  List<AuditEvent> _auditLog = [];
  String _searchQuery = '';
  VaultItemCategory? _filterCategory;
  Timer? _inactivityTimer;
  final LocalAuthentication _localAuth = LocalAuthentication();
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  String? _lastBiometricError;
  String _fullName = '';
  String _country = '';
  String _preferredLanguage = 'en';
  bool _profileComplete = false;

  bool get initialized => _initialized;
  bool get authenticated => _authenticated;
  bool get hasMasterPassword => _hasMasterPassword;
  bool get useBiometrics => _useBiometrics;
  bool get biometricAvailable => _biometricAvailable;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
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

  Future<void> saveUserProfile(String name, String country, String lang) async {
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

  List<VaultEntry> get filteredVault {
    var list = _vault.where((e) {
      final matchesSearch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e.website?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false) ||
          e.tags.any(
              (t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
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

    await _checkBiometricAvailability();

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

  Future<void> _checkBiometricAvailability() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      _biometricAvailable = canCheck && isSupported;
      if (_biometricAvailable) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        if (_availableBiometrics.isEmpty) {
          _biometricAvailable = false;
        }
      }
    } catch (_) {
      _biometricAvailable = false;
      _availableBiometrics = [];
    }
  }

  Future<void> setupMasterPassword(String password) async {
    final salt = CryptoEngine.generateSalt();
    final hash = CryptoEngine.hashPassword(password, salt);
    await CryptoEngine.storeSecure('master_salt', base64.encode(salt));
    await CryptoEngine.storeSecure('master_hash', hash);

    if (_vault.isNotEmpty) {
      await _reEncryptVaultWithPassword(password, salt);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_master_password', true);
    } catch (_) {}

    _hasMasterPassword = true;
    _authenticated = true;
    _failedAttempts = 0;
    _addAuditEvent('AUTH', 'Master password configured');
    _computeSecurityScore();
    _resetInactivityTimer();
    notifyListeners();
  }

  Future<bool> setupBiometrics() async {
    _lastBiometricError = null;
    await _checkBiometricAvailability();

    if (!_biometricAvailable) {
      _lastBiometricError = _availableBiometrics.isEmpty
          ? 'No fingerprint or face data enrolled. Add one in device settings first.'
          : 'This device does not support biometric authentication.';
      notifyListeners();
      return false;
    }

    try {
      final success = await _localAuth.authenticate(
        localizedReason: 'Register your biometrics to protect CipherGuard',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (success) {
        if (await CryptoEngine.readSecure('biometric_key') == null) {
          final newKey = CryptoEngine.generateSalt(32);
          await CryptoEngine.storeSecure(
              'biometric_key', base64.encode(newKey));
        }

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_biometrics', true);
        } catch (_) {}

        _useBiometrics = true;
        _authenticated = true;
        _failedAttempts = 0;
        _addAuditEvent('AUTH', 'Biometric authentication configured');
        _computeSecurityScore();
        _resetInactivityTimer();
        notifyListeners();
      } else {
        _lastBiometricError = 'Biometric registration was cancelled.';
        notifyListeners();
      }
      return success;
    } on PlatformException catch (e) {
      _lastBiometricError = _messageForBiometricError(e);
      notifyListeners();
      return false;
    } catch (_) {
      _lastBiometricError =
          'Could not start biometric registration. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<void> disableBiometrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('use_biometrics', false);
    } catch (_) {}
    _useBiometrics = false;
    _addAuditEvent('AUTH', 'Biometric authentication disabled');
    _computeSecurityScore();
    notifyListeners();
  }

  Future<void> removeMasterPassword() async {
    await CryptoEngine.deleteSecure('master_salt');
    await CryptoEngine.deleteSecure('master_hash');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_master_password', false);
    } catch (_) {}
    _hasMasterPassword = false;
    _addAuditEvent('AUTH', 'Master password removed');
    _computeSecurityScore();
    notifyListeners();
  }

  Future<bool> authenticateWithPassword(String password) async {
    if (isLockedOut) return false;

    try {
      final saltStr = await CryptoEngine.readSecure('master_salt');
      final hash = await CryptoEngine.readSecure('master_hash');
      if (saltStr == null || hash == null) return false;
      final salt = base64.decode(saltStr);
      final valid = CryptoEngine.verifyPassword(password, salt, hash);

      if (valid) {
        _authenticated = true;
        _failedAttempts = 0;
        _lockoutUntil = null;
        _addAuditEvent('AUTH', 'Password authentication successful');
        _resetInactivityTimer();
        notifyListeners();
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
          _addAuditEvent('SECURITY', 'Account locked due to failed attempts');
        }
        notifyListeners();
      }
      return valid;
    } catch (_) {
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    _lastBiometricError = null;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        _lastBiometricError =
            'This device does not support biometric authentication.';
        notifyListeners();
        return false;
      }
      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        _lastBiometricError =
            'No fingerprint or face data enrolled. Add one in device settings first.';
        notifyListeners();
        return false;
      }
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access CipherGuard vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated) {
        _authenticated = true;
        _failedAttempts = 0;
        _lockoutUntil = null;
        _addAuditEvent('AUTH', 'Biometric authentication successful');
        _resetInactivityTimer();
        notifyListeners();
      } else {
        _lastBiometricError = 'Biometric authentication was cancelled.';
        notifyListeners();
      }
      return authenticated;
    } on PlatformException catch (e) {
      _lastBiometricError = _messageForBiometricError(e);
      notifyListeners();
      return false;
    } catch (_) {
      _lastBiometricError =
          'Biometric authentication failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  String _messageForBiometricError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device.';
      case 'NotEnrolled':
        return 'No fingerprint or face data enrolled. Add one in device settings first.';
      case 'LockedOut':
        return 'Too many attempts. Biometric authentication is temporarily locked.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is locked. Unlock your device with PIN first.';
      case 'PasscodeNotSet':
        return 'Set up a device PIN or password before using biometrics.';
      default:
        return e.message ?? 'Biometric authentication failed. Please try again.';
    }
  }

  void setActiveTab(int tab) {
    _activeTab = tab;
    _resetInactivityTimer();
    notifyListeners();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: 5), () {
      _authenticated = false;
      _addAuditEvent('AUTH', 'Session expired due to inactivity');
      notifyListeners();
    });
  }

  void resetTimer() => _resetInactivityTimer();

  void lock() {
    _authenticated = false;
    _inactivityTimer?.cancel();
    _addAuditEvent('AUTH', 'Vault manually locked');
    notifyListeners();
  }

  Future<Uint8List> _getMasterKey() async {
    final saltStr = await CryptoEngine.readSecure('master_salt');
    if (saltStr != null) {
      final hash = await CryptoEngine.readSecure('master_hash');
      if (hash != null) {
        final salt = base64.decode(saltStr);
        final sessionKey = await CryptoEngine.readSecure('session_key');
        if (sessionKey != null) {
          return base64.decode(sessionKey);
        }
      }
    }

    var biometricKey = await CryptoEngine.readSecure('biometric_key');
    if (biometricKey == null) {
      final newKey = CryptoEngine.generateSalt(32);
      await CryptoEngine.storeSecure('biometric_key', base64.encode(newKey));
      biometricKey = base64.encode(newKey);
    }
    return base64.decode(biometricKey);
  }

  Future<void> storeSessionKey(String password) async {
    final saltStr = await CryptoEngine.readSecure('master_salt');
    if (saltStr == null) return;
    final salt = base64.decode(saltStr);
    final key = CryptoEngine.deriveKeyFromPassword(password, salt);
    await CryptoEngine.storeSecure('session_key', base64.encode(key));
  }

  Future<void> clearSessionKey() async {
    await CryptoEngine.deleteSecure('session_key');
  }

  Future<void> _reEncryptVaultWithPassword(
      String newPassword, Uint8List newSalt) async {
    final oldKey = await _getMasterKey();
    final newKey = CryptoEngine.deriveKeyFromPassword(newPassword, newSalt);

    for (final entry in _vault) {
      if (entry.encryptedSecret.isEmpty) continue;
      try {
        final plaintext =
            CryptoEngine.decryptData(entry.encryptedSecret, entry.iv, oldKey);
        final reEncrypted = CryptoEngine.encryptData(plaintext, newKey);
        entry.encryptedSecret = reEncrypted['ciphertext']!;
        entry.iv = reEncrypted['iv']!;
      } catch (_) {}
    }
    await _saveVault();
  }

  Future<void> addVaultEntry(VaultEntry entry) async {
    final key = await _getMasterKey();
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
    final key = await _getMasterKey();
    return CryptoEngine.decryptData(entry.encryptedSecret, entry.iv, key);
  }

  Future<void> updateVaultEntry(VaultEntry updated) async {
    final idx = _vault.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    if (updated.rawSecret.isNotEmpty) {
      final key = await _getMasterKey();
      final encrypted = CryptoEngine.encryptData(updated.rawSecret, key);
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
    final entry = _vault.firstWhere((e) => e.id == id);
    _vault.removeWhere((e) => e.id == id);
    await _saveVault();
    _computeSecurityScore();
    _addAuditEvent('VAULT', 'Deleted: ${entry.title}');
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    final idx = _vault.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _vault[idx].isFavorite = !_vault[idx].isFavorite;
    await _saveVault();
    notifyListeners();
  }

  Future<void> _saveVault() async {
    try {
      final data = _vault.map((e) => e.toJson()).toList();
      await CryptoEngine.storeSecure('vault_v2', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadVault() async {
    final data = await CryptoEngine.readSecure('vault_v2');
    if (data != null && data.isNotEmpty) {
      try {
        final list = jsonDecode(data) as List;
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
    if (_auditLog.length > 200) _auditLog = _auditLog.sublist(0, 200);
    _saveAuditLog();
  }

  Future<void> _loadAuditLog() async {
    final data = await CryptoEngine.readSecure('audit_log');
    if (data != null && data.isNotEmpty) {
      try {
        final list = jsonDecode(data) as List;
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

  void _computeSecurityScore() {
    int score = 0;
    if (_hasMasterPassword) score += 20;
    if (_useBiometrics) score += 20;
    if (_vault.isNotEmpty) score += 15;
    final weakCount = weakPasswordCount;
    if (weakCount == 0 && _vault.isNotEmpty) {
      score += 20;
    } else if (weakCount < 3) {
      score += 10;
    }
    final dupCount = duplicatePasswordCount;
    if (dupCount == 0 && _vault.isNotEmpty) {
      score += 15;
    } else if (dupCount < 2) {
      score += 7;
    }
    score += min(10, _vault.length ~/ 2);
    _securityScore = score.clamp(0, 100);
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }
}
