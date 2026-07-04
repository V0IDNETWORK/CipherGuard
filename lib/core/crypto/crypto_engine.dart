import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class CryptoEngine {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Uint8List generateSalt([int length = 32]) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static Uint8List generateIV([int length = 12]) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static Uint8List deriveKeyFromPassword(String password, Uint8List salt,
      {int iterations = 100000, int keyLength = 32}) {
    final passwordBytes = utf8.encode(password);
    final hmacKey = passwordBytes;

    Uint8List u = Uint8List.fromList(
        Hmac(sha256, hmacKey).convert([...salt, 0, 0, 0, 1]).bytes);
    Uint8List t = Uint8List.fromList(u);

    for (int i = 1; i < iterations; i++) {
      u = Uint8List.fromList(Hmac(sha256, hmacKey).convert(u).bytes);
      for (int j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t.sublist(0, keyLength);
  }

  static Map<String, String> encryptData(String plaintext, Uint8List key) {
    final iv = generateIV();
    final encKey = enc.Key(key);
    final encIV = enc.IV(iv);
    final encrypter = enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plaintext, iv: encIV);
    return {
      'ciphertext': base64.encode(encrypted.bytes),
      'iv': base64.encode(iv),
    };
  }

  static String decryptData(String ciphertext, String ivStr, Uint8List key) {
    final iv = base64.decode(ivStr);
    final ciphertextBytes = base64.decode(ciphertext);
    final encKey = enc.Key(key);
    final encIV = enc.IV(iv);
    final encrypter = enc.Encrypter(enc.AES(encKey, mode: enc.AESMode.gcm));
    return encrypter.decrypt(enc.Encrypted(ciphertextBytes), iv: encIV);
  }

  static Future<void> storeSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  static Future<String?> readSecure(String key) async {
    return _secureStorage.read(key: key);
  }

  static Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  static Future<void> deleteAllSecure() async {
    await _secureStorage.deleteAll();
  }

  static String hashPassword(String password, Uint8List salt) {
    final passwordBytes = utf8.encode(password);
    final hmac = Hmac(sha256, passwordBytes);
    final firstPass = hmac.convert(salt).bytes;
    final hmac2 = Hmac(sha256, passwordBytes);
    return hmac2.convert([...salt, ...firstPass]).toString();
  }

  static bool verifyPassword(String password, Uint8List salt, String hash) =>
      hashPassword(password, salt) == hash;

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
    const sy = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
    final pool = (upper ? up : '') +
        (lower ? lo : '') +
        (digits ? di : '') +
        (symbols ? sy : '');
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
