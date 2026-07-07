import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

// Singleton-style accessor so the storage instance is created once after
// WidgetsFlutterBinding.ensureInitialized() has been called, avoiding the
// MissingPluginException that fires when a static const field initialises
// the plugin channel before the binding is ready.
class CryptoEngine {
  CryptoEngine._();

  static FlutterSecureStorage? _storage;

  static FlutterSecureStorage get _store {
    _storage ??= const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        keyCipherAlgorithm:
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    );
    return _storage!;
  }

  // ── Random material ────────────────────────────────────────────────────────

  static Uint8List generateSalt([int length = 32]) {
    final rng = Random.secure();
    return Uint8List.fromList(
        List.generate(length, (_) => rng.nextInt(256)));
  }

  // ── Key derivation (PBKDF2-HMAC-SHA256) ────────────────────────────────────
  // Standard RFC 2898 PBKDF2 with one 32-byte block (sufficient for a 256-bit
  // key).  100 000 iterations is the OWASP minimum for PBKDF2-HMAC-SHA256.

  static Uint8List deriveKeyFromPassword(
    String password,
    Uint8List salt, {
    int iterations = 100000,
    int keyLength = 32,
  }) {
    final passwordBytes = utf8.encode(password);

    // PRF: HMAC-SHA256
    Uint8List prf(Uint8List data) =>
        Uint8List.fromList(Hmac(sha256, passwordBytes).convert(data).bytes);

    // Block 1: PRF(password, salt || INT(1))
    final saltBlock = Uint8List(salt.length + 4);
    saltBlock.setRange(0, salt.length, salt);
    saltBlock[salt.length] = 0;
    saltBlock[salt.length + 1] = 0;
    saltBlock[salt.length + 2] = 0;
    saltBlock[salt.length + 3] = 1;

    Uint8List u = prf(saltBlock);
    final t = Uint8List.fromList(u);

    for (int i = 1; i < iterations; i++) {
      u = prf(u);
      for (int j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t.sublist(0, keyLength);
  }

  // ── AES-256-GCM ────────────────────────────────────────────────────────────

  static Map<String, String> encryptData(String plaintext, Uint8List key) {
    assert(key.length == 32, 'AES-256 requires a 32-byte key');
    final iv = Uint8List.fromList(
        List.generate(12, (_) => Random.secure().nextInt(256)));
    final encKey = enc.Key(key);
    final encIV = enc.IV(iv);
    final encrypter =
        enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: encIV);
    return {
      'ciphertext': base64.encode(encrypted.bytes),
      'iv': base64.encode(iv),
    };
  }

  static String decryptData(
      String ciphertext, String ivStr, Uint8List key) {
    assert(key.length == 32, 'AES-256 requires a 32-byte key');
    final iv = base64.decode(ivStr);
    final ciphertextBytes = base64.decode(ciphertext);
    final encKey = enc.Key(key);
    final encIV = enc.IV(iv);
    final encrypter =
        enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.gcm));
    return encrypter.decrypt(enc.Encrypted(ciphertextBytes), iv: encIV);
  }

  // ── Secure storage ─────────────────────────────────────────────────────────

  static Future<void> storeSecure(String key, String value) async {
    await _store.write(key: key, value: value);
  }

  static Future<String?> readSecure(String key) async {
    return _store.read(key: key);
  }

  static Future<void> deleteSecure(String key) async {
    await _store.delete(key: key);
  }

  static Future<void> deleteAllSecure() async {
    await _store.deleteAll();
  }

  // ── Password hashing (HMAC-SHA256 with salt, 2-round stretch) ─────────────
  // Not bcrypt/Argon2 (those aren't available as pure-Dart packages that work
  // on all Flutter targets without FFI).  The vault encryption key is derived
  // separately via PBKDF2, so this hash is used only for fast "is this the
  // right password?" verification; the actual vault key comes from
  // deriveKeyFromPassword().

  static String hashPassword(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final inner = Hmac(sha256, passwordBytes).convert(salt).bytes;
    return Hmac(sha256, passwordBytes)
        .convert([...salt, ...inner])
        .toString();
  }

  static bool verifyPassword(
          String password, Uint8List salt, String hash) =>
      hashPassword(password, salt) == hash;

  // ── Password utilities ─────────────────────────────────────────────────────

  static String generateStrongPassword({
    int length = 24,
    bool upper = true,
    bool lower = true,
    bool digits = true,
    bool symbols = true,
  }) {
    const up = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const lo = 'abcdefghijklmnopqrstuvwxyz';
    const di = '0123456789';
    const sy = r'!@#$%^&*()_+-=[]{}|;:,.<>?';
    final pool =
        (upper ? up : '') + (lower ? lo : '') + (digits ? di : '') + (symbols ? sy : '');
    if (pool.isEmpty) return '';
    final rng = Random.secure();
    final required = <String>[
      if (upper) up[rng.nextInt(up.length)],
      if (lower) lo[rng.nextInt(lo.length)],
      if (digits) di[rng.nextInt(di.length)],
      if (symbols) sy[rng.nextInt(sy.length)],
    ];
    final rest = List.generate(
        length - required.length, (_) => pool[rng.nextInt(pool.length)]);
    return ([...required, ...rest]..shuffle(rng)).join();
  }

  static int analyzePasswordStrength(String pwd) {
    int score = 0;
    if (pwd.length >= 8) score += 15;
    if (pwd.length >= 12) score += 15;
    if (pwd.length >= 16) score += 10;
    if (pwd.contains(RegExp(r'[A-Z]'))) score += 15;
    if (pwd.contains(RegExp(r'[a-z]'))) score += 10;
    if (pwd.contains(RegExp(r'[0-9]'))) score += 15;
    if (pwd.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score += 20;
    return score.clamp(0, 100);
  }

  static String strengthLabel(int score) {
    if (score < 25) return 'CRITICAL';
    if (score < 50) return 'WEAK';
    if (score < 75) return 'MODERATE';
    if (score < 90) return 'STRONG';
    return 'FORTRESS';
  }

  static Color strengthColor(int score) {
    if (score < 25) return kError;
    if (score < 50) return const Color(0xFFFF6B00);
    if (score < 75) return kWarning;
    if (score < 90) return kSuccess;
    return kCyan;
  }
}
