import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF050505),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const CipherGuardApp());
}

// ════════════════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ════════════════════════════════════════════════════════════════════════════

const Color kBg = Color(0xFF050505);
const Color kSurface = Color(0xFF0A0A0A);
const Color kSurface2 = Color(0xFF111118);
const Color kSurface3 = Color(0xFF161624);
const Color kPrimary = Color(0xFF8A2BE2);
const Color kSecondary = Color(0xFFB026FF);
const Color kAccent = Color(0xFF6F00FF);
const Color kNeon = Color(0xFFCC66FF);
const Color kCyan = Color(0xFF00D4FF);
const Color kText = Color(0xFFFFFFFF);
const Color kTextDim = Color(0xFF9B9B9B);
const Color kTextMuted = Color(0xFF555566);
const Color kGlass = Color(0x12FFFFFF);
const Color kGlass2 = Color(0x08FFFFFF);
const Color kGlassBorder = Color(0x33CC66FF);
const Color kGlassBorder2 = Color(0x1ACC66FF);
const Color kError = Color(0xFFFF2E63);
const Color kSuccess = Color(0xFF00FF88);
const Color kWarning = Color(0xFFFFB800);
const Color kInfo = Color(0xFF00D4FF);

class T {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double r4 = 4;
  static const double r8 = 8;
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
  static const double r24 = 24;
  static const double r32 = 32;
}

class AppColors {
  static const List<Color> gradientPrimary = [Color(0xFF8A2BE2), Color(0xFF6F00FF)];
  static const List<Color> gradientSecondary = [Color(0xFFB026FF), Color(0xFF8A2BE2)];
  static const List<Color> gradientNeon = [Color(0xFFCC66FF), Color(0xFF8A2BE2)];
  static const List<Color> gradientCyan = [Color(0xFF00D4FF), Color(0xFF6F00FF)];
  static const List<Color> gradientFire = [Color(0xFFFF2E63), Color(0xFFB026FF)];
  static const List<Color> gradientSuccess = [Color(0xFF00FF88), Color(0xFF00D4FF)];
  static const List<Color> gradientGold = [Color(0xFFFFB800), Color(0xFFFF6B00)];
  static const List<Color> gradientDark = [Color(0xFF111118), Color(0xFF050505)];
}

// ════════════════════════════════════════════════════════════════════════════
// THEME
// ════════════════════════════════════════════════════════════════════════════

class AppTheme {
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary,
          secondary: kSecondary,
          surface: kSurface,
          error: kError,
        ),
        fontFamily: 'Rajdhani',
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, letterSpacing: 2),
          displayMedium: TextStyle(color: kText, fontWeight: FontWeight.w600, letterSpacing: 1.5),
          headlineLarge: TextStyle(color: kText, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          headlineMedium: TextStyle(color: kText, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: kText, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          bodyLarge: TextStyle(color: kText),
          bodyMedium: TextStyle(color: kTextDim),
          bodySmall: TextStyle(color: kTextDim, fontSize: 11),
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// CRYPTO ENGINE — AES-256-GCM + PBKDF2-SHA256
// ════════════════════════════════════════════════════════════════════════════

class CryptoEngine {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  );

  static Uint8List generateSalt([int length = 32]) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static Uint8List generateIV([int length = 12]) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => rng.nextInt(256)));
  }

  static Uint8List deriveKey(String password, Uint8List salt,
      {int iterations = 200000, int keyLength = 32}) {
    final passwordBytes = utf8.encode(password);
    var key = Uint8List.fromList(passwordBytes + salt);
    for (int i = 0; i < iterations; i++) {
      key = Uint8List.fromList(sha256.convert(key).bytes);
    }
    return key.sublist(0, keyLength);
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

  static Future<void> storeSecure(String key, String value) async =>
      await _secureStorage.write(key: key, value: value);

  static Future<String?> readSecure(String key) async =>
      await _secureStorage.read(key: key);

  static Future<void> deleteSecure(String key) async =>
      await _secureStorage.delete(key: key);

  static String hashPassword(String password, Uint8List salt) {
    final bytes = utf8.encode(password);
    final combined = Uint8List.fromList(bytes + salt);
    return sha256.convert(sha256.convert(combined).bytes).toString();
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
    final pool = (upper ? up : '') + (lower ? lo : '') + (digits ? di : '') + (symbols ? sy : '');
    final rng = Random.secure();
    final required = <String>[
      if (upper) up[rng.nextInt(up.length)],
      if (lower) lo[rng.nextInt(lo.length)],
      if (digits) di[rng.nextInt(di.length)],
      if (symbols) sy[rng.nextInt(sy.length)],
    ];
    final rest = List.generate(length - required.length, (_) => pool[rng.nextInt(pool.length)]);
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

// ════════════════════════════════════════════════════════════════════════════
// PERMISSION SERVICE
// ════════════════════════════════════════════════════════════════════════════

class PermissionService {
  static Future<bool> requestBiometricPermission() async {
    if (kIsWeb) return true;
    return true;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ════════════════════════════════════════════════════════════════════════════

enum VaultItemCategory {
  login,
  secureNote,
  creditCard,
  identity,
  sshKey,
  apiKey,
  license,
  secret,
  bankAccount,
}

extension VaultItemCategoryX on VaultItemCategory {
  String get label {
    switch (this) {
      case VaultItemCategory.login: return 'Login';
      case VaultItemCategory.secureNote: return 'Secure Note';
      case VaultItemCategory.creditCard: return 'Credit Card';
      case VaultItemCategory.identity: return 'Identity';
      case VaultItemCategory.sshKey: return 'SSH Key';
      case VaultItemCategory.apiKey: return 'API Key';
      case VaultItemCategory.license: return 'License';
      case VaultItemCategory.secret: return 'Secret';
      case VaultItemCategory.bankAccount: return 'Bank Account';
    }
  }

  IconData get icon {
    switch (this) {
      case VaultItemCategory.login: return Icons.lock_rounded;
      case VaultItemCategory.secureNote: return Icons.note_rounded;
      case VaultItemCategory.creditCard: return Icons.credit_card_rounded;
      case VaultItemCategory.identity: return Icons.badge_rounded;
      case VaultItemCategory.sshKey: return Icons.terminal_rounded;
      case VaultItemCategory.apiKey: return Icons.api_rounded;
      case VaultItemCategory.license: return Icons.verified_rounded;
      case VaultItemCategory.secret: return Icons.security_rounded;
      case VaultItemCategory.bankAccount: return Icons.account_balance_rounded;
    }
  }

  List<Color> get gradient {
    switch (this) {
      case VaultItemCategory.login: return AppColors.gradientPrimary;
      case VaultItemCategory.secureNote: return AppColors.gradientCyan;
      case VaultItemCategory.creditCard: return AppColors.gradientGold;
      case VaultItemCategory.identity: return AppColors.gradientSuccess;
      case VaultItemCategory.sshKey: return [const Color(0xFF00FF88), const Color(0xFF00D4FF)];
      case VaultItemCategory.apiKey: return AppColors.gradientNeon;
      case VaultItemCategory.license: return AppColors.gradientGold;
      case VaultItemCategory.secret: return AppColors.gradientFire;
      case VaultItemCategory.bankAccount: return AppColors.gradientSuccess;
    }
  }
}

class VaultEntry {
  final String id;
  String title;
  String username;
  String encryptedSecret;
  String iv;
  String rawSecret;
  VaultItemCategory category;
  String? website;
  String? notes;
  List<String> tags;
  DateTime createdAt;
  DateTime? updatedAt;
  bool isFavorite;
  int strengthScore;

  VaultEntry({
    required this.id,
    required this.title,
    required this.username,
    this.encryptedSecret = '',
    this.iv = '',
    this.rawSecret = '',
    required this.category,
    this.website,
    this.notes,
    List<String>? tags,
    required this.createdAt,
    this.updatedAt,
    this.isFavorite = false,
    this.strengthScore = 0,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'username': username,
        'encryptedSecret': encryptedSecret,
        'iv': iv,
        'category': category.index,
        'website': website,
        'notes': notes,
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isFavorite': isFavorite,
        'strengthScore': strengthScore,
      };

  factory VaultEntry.fromJson(Map<String, dynamic> j) => VaultEntry(
        id: j['id'] as String,
        title: j['title'] as String,
        username: j['username'] as String? ?? '',
        encryptedSecret: j['encryptedSecret'] as String? ?? '',
        iv: j['iv'] as String? ?? '',
        category: VaultItemCategory.values[(j['category'] as int?) ?? 0],
        website: j['website'] as String?,
        notes: j['notes'] as String?,
        tags: (j['tags'] as List?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: j['updatedAt'] != null ? DateTime.parse(j['updatedAt'] as String) : null,
        isFavorite: j['isFavorite'] as bool? ?? false,
        strengthScore: j['strengthScore'] as int? ?? 0,
      );
}

class AuditEvent {
  final String id;
  final String action;
  final String detail;
  final DateTime timestamp;

  AuditEvent({required this.id, required this.action, required this.detail, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AuditEvent.fromJson(Map<String, dynamic> j) => AuditEvent(
        id: j['id'] as String,
        action: j['action'] as String,
        detail: j['detail'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// APP STATE (ChangeNotifier)
// ════════════════════════════════════════════════════════════════════════════

const Map<String, Map<String, String>> kLangStrings = {
  'en': {
    'app_name': 'CipherGuard',
    'dashboard': 'Dashboard',
    'vault': 'Vault',
    'security': 'Security',
    'info': 'Info',
    'security_overview': 'SECURITY OVERVIEW',
    'welcome': 'Welcome',
    'unlock_vault': 'UNLOCK VAULT',
    'authenticating': 'AUTHENTICATING...',
    'master_password': 'Master Password',
    'auth_required': 'AUTHENTICATION REQUIRED',
    'greeting': 'Hello',
    'settings': 'SETTINGS',
    'language': 'Language',
    'full_name': 'Full Name',
    'country': 'Country',
    'preferred_language': 'Preferred Language',
    'get_started': 'GET STARTED',
    'next': 'NEXT',
    'back': 'BACK',
    'complete': 'COMPLETE SETUP',
    'choose_protection': 'CHOOSE YOUR\nPROTECTION',
    'select_auth': 'SELECT YOUR PRIMARY AUTHENTICATION METHOD',
    'initialize': 'INITIALIZE CIPHERGUARD',
    'developer': 'Developer',
    'portfolio': 'Portfolio',
    'contact': 'Contact',
    'skills': 'Skills',
    'about_dev': 'About Developer',
    'add_entry': 'ADD ENTRY',
    'search': 'Search...',
    'no_items': 'Vault is empty',
    'add_first': 'Add your first secure item',
    'weak_passwords': 'Weak Passwords',
    'duplicate_passwords': 'Duplicate Passwords',
    'at_risk': 'At-Risk Items',
    'threat_analysis': 'THREAT ANALYSIS',
    'encryption_details': 'ENCRYPTION DETAILS',
    'audit_log': 'AUDIT LOG',
  },
  'fa': {
    'app_name': 'سایفرگارد',
    'dashboard': 'داشبورد',
    'vault': 'خزانه',
    'security': 'امنیت',
    'info': 'اطلاعات',
    'security_overview': 'نمای کلی امنیت',
    'welcome': 'خوش آمدید',
    'unlock_vault': 'باز کردن خزانه',
    'authenticating': 'در حال احراز هویت...',
    'master_password': 'رمز عبور اصلی',
    'auth_required': 'احراز هویت الزامی است',
    'greeting': 'سلام',
    'settings': 'تنظیمات',
    'language': 'زبان',
    'full_name': 'نام کامل',
    'country': 'کشور',
    'preferred_language': 'زبان ترجیحی',
    'get_started': 'شروع کنید',
    'next': 'بعدی',
    'back': 'قبلی',
    'complete': 'تکمیل راه‌اندازی',
    'choose_protection': 'روش\nحفاظت را انتخاب کنید',
    'select_auth': 'روش احراز هویت اصلی را انتخاب کنید',
    'initialize': 'راه‌اندازی سایفرگارد',
    'developer': 'توسعه‌دهنده',
    'portfolio': 'نمونه کار',
    'contact': 'تماس',
    'skills': 'مهارت‌ها',
    'about_dev': 'درباره توسعه‌دهنده',
    'add_entry': 'افزودن مورد',
    'search': 'جستجو...',
    'no_items': 'خزانه خالی است',
    'add_first': 'اولین مورد امن خود را اضافه کنید',
    'weak_passwords': 'رمزهای ضعیف',
    'duplicate_passwords': 'رمزهای تکراری',
    'at_risk': 'موارد در معرض خطر',
    'threat_analysis': 'تحلیل تهدیدات',
    'encryption_details': 'جزئیات رمزنگاری',
    'audit_log': 'گزارش حسابرسی',
  },
  'ar': {
    'app_name': 'سايفرغارد',
    'dashboard': 'لوحة التحكم',
    'vault': 'الخزينة',
    'security': 'الأمان',
    'info': 'معلومات',
    'security_overview': 'نظرة عامة على الأمان',
    'welcome': 'مرحباً',
    'unlock_vault': 'فتح الخزينة',
    'authenticating': 'جارٍ المصادقة...',
    'master_password': 'كلمة المرور الرئيسية',
    'auth_required': 'المصادقة مطلوبة',
    'greeting': 'مرحباً',
    'settings': 'الإعدادات',
    'language': 'اللغة',
    'full_name': 'الاسم الكامل',
    'country': 'الدولة',
    'preferred_language': 'اللغة المفضلة',
    'get_started': 'ابدأ الآن',
    'next': 'التالي',
    'back': 'السابق',
    'complete': 'إتمام الإعداد',
    'choose_protection': 'اختر\nطريقة الحماية',
    'select_auth': 'اختر طريقة المصادقة الأساسية',
    'initialize': 'تهيئة سايفرغارد',
    'developer': 'المطور',
    'portfolio': 'معرض الأعمال',
    'contact': 'التواصل',
    'skills': 'المهارات',
    'about_dev': 'عن المطور',
    'add_entry': 'إضافة إدخال',
    'search': 'بحث...',
    'no_items': 'الخزينة فارغة',
    'add_first': 'أضف أول عنصر آمن لديك',
    'weak_passwords': 'كلمات المرور الضعيفة',
    'duplicate_passwords': 'كلمات المرور المكررة',
    'at_risk': 'العناصر المعرضة للخطر',
    'threat_analysis': 'تحليل التهديدات',
    'encryption_details': 'تفاصيل التشفير',
    'audit_log': 'سجل التدقيق',
  },
  'tr': {
    'app_name': 'CipherGuard',
    'dashboard': 'Gösterge',
    'vault': 'Kasa',
    'security': 'Güvenlik',
    'info': 'Bilgi',
    'security_overview': 'GÜVENLİK GÖRÜNÜMÜ',
    'welcome': 'Hoş Geldiniz',
    'unlock_vault': 'KASAYI AÇ',
    'authenticating': 'KİMLİK DOĞRULANYOR...',
    'master_password': 'Ana Parola',
    'auth_required': 'KİMLİK DOĞRULAMA GEREKLİ',
    'greeting': 'Merhaba',
    'settings': 'AYARLAR',
    'language': 'Dil',
    'full_name': 'Ad Soyad',
    'country': 'Ülke',
    'preferred_language': 'Tercih Edilen Dil',
    'get_started': 'BAŞLA',
    'next': 'İLERİ',
    'back': 'GERİ',
    'complete': 'KURULUMU TAMAMLA',
    'choose_protection': 'KORUMA\nYÖNTEMİNİZİ SEÇİN',
    'select_auth': 'ANA KİMLİK DOĞRULAMA YÖNTEMİNİZİ SEÇİN',
    'initialize': 'CIPHERGUARD\'I BAŞLAT',
    'developer': 'Geliştirici',
    'portfolio': 'Portfolyo',
    'contact': 'İletişim',
    'skills': 'Beceriler',
    'about_dev': 'Geliştirici Hakkında',
    'add_entry': 'GİRİŞ EKLE',
    'search': 'Ara...',
    'no_items': 'Kasa boş',
    'add_first': 'İlk güvenli öğenizi ekleyin',
    'weak_passwords': 'Zayıf Parolalar',
    'duplicate_passwords': 'Yinelenen Parolalar',
    'at_risk': 'Risk Altındaki Öğeler',
    'threat_analysis': 'TEHDİT ANALİZİ',
    'encryption_details': 'ŞİFRELEME DETAYLARI',
    'audit_log': 'DENETİM GÜNLÜĞÜ',
  },
  'ru': {
    'app_name': 'CipherGuard',
    'dashboard': 'Панель',
    'vault': 'Хранилище',
    'security': 'Безопасность',
    'info': 'Инфо',
    'security_overview': 'ОБЗОР БЕЗОПАСНОСТИ',
    'welcome': 'Добро пожаловать',
    'unlock_vault': 'ОТКРЫТЬ ХРАНИЛИЩЕ',
    'authenticating': 'АУТЕНТИФИКАЦИЯ...',
    'master_password': 'Мастер-пароль',
    'auth_required': 'ТРЕБУЕТСЯ АУТЕНТИФИКАЦИЯ',
    'greeting': 'Привет',
    'settings': 'НАСТРОЙКИ',
    'language': 'Язык',
    'full_name': 'Полное имя',
    'country': 'Страна',
    'preferred_language': 'Предпочитаемый язык',
    'get_started': 'НАЧАТЬ',
    'next': 'ДАЛЕЕ',
    'back': 'НАЗАД',
    'complete': 'ЗАВЕРШИТЬ НАСТРОЙКУ',
    'choose_protection': 'ВЫБЕРИТЕ\nМЕТОД ЗАЩИТЫ',
    'select_auth': 'ВЫБЕРИТЕ ОСНОВНОЙ МЕТОД АУТЕНТИФИКАЦИИ',
    'initialize': 'ИНИЦИАЛИЗИРОВАТЬ CIPHERGUARD',
    'developer': 'Разработчик',
    'portfolio': 'Портфолио',
    'contact': 'Контакты',
    'skills': 'Навыки',
    'about_dev': 'О разработчике',
    'add_entry': 'ДОБАВИТЬ',
    'search': 'Поиск...',
    'no_items': 'Хранилище пусто',
    'add_first': 'Добавьте первый защищённый элемент',
    'weak_passwords': 'Слабые пароли',
    'duplicate_passwords': 'Повторяющиеся пароли',
    'at_risk': 'Уязвимые элементы',
    'threat_analysis': 'АНАЛИЗ УГРОЗ',
    'encryption_details': 'СВЕДЕНИЯ О ШИФРОВАНИИ',
    'audit_log': 'ЖУРНАЛ АУДИТА',
  },
  'de': {
    'app_name': 'CipherGuard',
    'dashboard': 'Dashboard',
    'vault': 'Tresor',
    'security': 'Sicherheit',
    'info': 'Info',
    'security_overview': 'SICHERHEITSÜBERSICHT',
    'welcome': 'Willkommen',
    'unlock_vault': 'TRESOR ÖFFNEN',
    'authenticating': 'AUTHENTIFIZIERUNG...',
    'master_password': 'Master-Passwort',
    'auth_required': 'AUTHENTIFIZIERUNG ERFORDERLICH',
    'greeting': 'Hallo',
    'settings': 'EINSTELLUNGEN',
    'language': 'Sprache',
    'full_name': 'Vollständiger Name',
    'country': 'Land',
    'preferred_language': 'Bevorzugte Sprache',
    'get_started': 'LOSLEGEN',
    'next': 'WEITER',
    'back': 'ZURÜCK',
    'complete': 'SETUP ABSCHLIESSEN',
    'choose_protection': 'SCHUTZ\nAUSWÄHLEN',
    'select_auth': 'WÄHLEN SIE IHRE AUTHENTIFIZIERUNGSMETHODE',
    'initialize': 'CIPHERGUARD INITIALISIEREN',
    'developer': 'Entwickler',
    'portfolio': 'Portfolio',
    'contact': 'Kontakt',
    'skills': 'Fähigkeiten',
    'about_dev': 'Über den Entwickler',
    'add_entry': 'EINTRAG HINZUFÜGEN',
    'search': 'Suchen...',
    'no_items': 'Tresor ist leer',
    'add_first': 'Fügen Sie Ihr erstes Element hinzu',
    'weak_passwords': 'Schwache Passwörter',
    'duplicate_passwords': 'Doppelte Passwörter',
    'at_risk': 'Gefährdete Elemente',
    'threat_analysis': 'BEDROHUNGSANALYSE',
    'encryption_details': 'VERSCHLÜSSELUNGSDETAILS',
    'audit_log': 'PRÜFPROTOKOLL',
  },
  'fr': {
    'app_name': 'CipherGuard',
    'dashboard': 'Tableau',
    'vault': 'Coffre',
    'security': 'Sécurité',
    'info': 'Info',
    'security_overview': 'APERÇU DE SÉCURITÉ',
    'welcome': 'Bienvenue',
    'unlock_vault': 'OUVRIR LE COFFRE',
    'authenticating': 'AUTHENTIFICATION...',
    'master_password': 'Mot de passe maître',
    'auth_required': 'AUTHENTIFICATION REQUISE',
    'greeting': 'Bonjour',
    'settings': 'PARAMÈTRES',
    'language': 'Langue',
    'full_name': 'Nom complet',
    'country': 'Pays',
    'preferred_language': 'Langue préférée',
    'get_started': 'COMMENCER',
    'next': 'SUIVANT',
    'back': 'RETOUR',
    'complete': 'TERMINER LA CONFIGURATION',
    'choose_protection': 'CHOISIR\nLA PROTECTION',
    'select_auth': 'SÉLECTIONNEZ VOTRE MÉTHODE D\'AUTHENTIFICATION',
    'initialize': 'INITIALISER CIPHERGUARD',
    'developer': 'Développeur',
    'portfolio': 'Portfolio',
    'contact': 'Contact',
    'skills': 'Compétences',
    'about_dev': 'À propos du développeur',
    'add_entry': 'AJOUTER',
    'search': 'Rechercher...',
    'no_items': 'Coffre vide',
    'add_first': 'Ajoutez votre premier élément sécurisé',
    'weak_passwords': 'Mots de passe faibles',
    'duplicate_passwords': 'Mots de passe dupliqués',
    'at_risk': 'Éléments à risque',
    'threat_analysis': 'ANALYSE DES MENACES',
    'encryption_details': 'DÉTAILS DE CHIFFREMENT',
    'audit_log': 'JOURNAL D\'AUDIT',
  },
};

const List<Map<String, String>> kSupportedLanguages = [
  {'code': 'en', 'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
  {'code': 'fa', 'name': 'Persian', 'native': 'فارسی', 'flag': '🇮🇷'},
  {'code': 'ar', 'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
  {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe', 'flag': '🇹🇷'},
  {'code': 'ru', 'name': 'Russian', 'native': 'Русский', 'flag': '🇷🇺'},
  {'code': 'de', 'name': 'German', 'native': 'Deutsch', 'flag': '🇩🇪'},
  {'code': 'fr', 'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
];

const List<String> kCountries = [
  'Afghanistan', 'Albania', 'Algeria', 'Argentina',  'Australia',
  'Austria', 'Azerbaijan', 'Bahrain', 'Bangladesh', 'Belarus', 'Belgium',
  'Bolivia', 'Bosnia', 'Brazil', 'Bulgaria', 'Cambodia', 'Canada', 'Chile',
  'China', 'Colombia', 'Croatia', 'Cuba', 'Cyprus', 'Czech Republic',
  'Denmark', 'Ecuador', 'Egypt', 'Estonia', 'Ethiopia', 'Finland', 'France',
  'Georgia', 'Germany', 'Ghana', 'Greece', 'Hungary', 'India', 'Indonesia',
  'Iran', 'Iraq', 'Ireland', 'Italy', 'Japan', 'Jordan', 'Kazakhstan',
  'Kenya', 'Kuwait', 'Kyrgyzstan', 'Latvia', 'Lebanon', 'Libya', 'Lithuania',
  'Luxembourg', 'Malaysia', 'Mexico', 'Moldova', 'Morocco', 'Netherlands',
  'New Zealand', 'Nigeria', 'North Korea', 'Norway', 'Oman', 'Pakistan',
  'Palestine', 'Peru', 'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania',
  'Russia', 'Saudi Arabia', 'Serbia', 'Singapore', 'Slovakia', 'Slovenia',
  'South Africa', 'South Korea', 'Spain', 'Sri Lanka', 'Sudan', 'Sweden',
  'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Thailand', 'Tunisia',
  'Turkey', 'Turkmenistan', 'Ukraine', 'United Arab Emirates', 'United Kingdom',
  'United States', 'Uruguay', 'Uzbekistan', 'Venezuela', 'Vietnam', 'Yemen',
];

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_full_name', name);
    await prefs.setString('user_country', country);
    await prefs.setString('user_language', lang);
    await prefs.setBool('profile_complete', true);
    notifyListeners();
  }

  Future<void> updateLanguage(String lang) async {
    _preferredLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_language', lang);
    notifyListeners();
  }

  List<VaultEntry> get filteredVault {
    var list = _vault.where((e) {
      final matchesSearch = _searchQuery.isEmpty ||
          e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (e.website?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          e.tags.any((t) => t.toLowerCase().contains(_searchQuery.toLowerCase()));
      final matchesCategory = _filterCategory == null || e.category == _filterCategory;
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

  int get weakPasswordCount =>
      _vault.where((e) => e.category == VaultItemCategory.login && e.strengthScore < 50).length;

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
    final prefs = await SharedPreferences.getInstance();
    _hasMasterPassword = prefs.getBool('has_master_password') ?? false;
    _useBiometrics = prefs.getBool('use_biometrics') ?? false;
    _profileComplete = prefs.getBool('profile_complete') ?? false;
    _fullName = prefs.getString('user_full_name') ?? '';
    _country = prefs.getString('user_country') ?? '';
    _preferredLanguage = prefs.getString('user_language') ?? 'en';
    await _checkBiometricAvailability();
    _initialized = true;
    await _loadVault();
    await _loadAuditLog();
    _computeSecurityScore();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_master_password', true);
    await prefs.setBool('use_biometrics', false);
    _hasMasterPassword = true;
    _useBiometrics = false;
    _authenticated = true;
    _failedAttempts = 0;
    _addAuditEvent('AUTH', 'Master password configured');
    _computeSecurityScore();
    _resetInactivityTimer();
    notifyListeners();
  }

  Future<bool> setupBiometrics() async {
    _lastBiometricError = null;
    await PermissionService.requestBiometricPermission();
    await _checkBiometricAvailability();
    if (!_biometricAvailable) {
      _lastBiometricError = _availableBiometrics.isEmpty
          ? 'No fingerprint or face data is enrolled on this device. Add one in your device settings first.'
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
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('use_biometrics', true);
        await prefs.setBool('has_master_password', false);
        _useBiometrics = true;
        _hasMasterPassword = false;
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
      _lastBiometricError = 'Could not start biometric registration. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> authenticateWithPassword(String password) async {
    if (isLockedOut) return false;
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
  }

  Future<bool> authenticateWithBiometrics() async {
    _lastBiometricError = null;
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        _lastBiometricError = 'This device does not support biometric authentication.';
        notifyListeners();
        return false;
      }
      final available = await _localAuth.getAvailableBiometrics();
      if (available.isEmpty) {
        _lastBiometricError = 'No fingerprint or face data is enrolled on this device. Add one in your device settings first.';
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
      _lastBiometricError = 'Biometric authentication failed. Please try again.';
      notifyListeners();
      return false;
    }
  }

  String _messageForBiometricError(PlatformException e) {
    switch (e.code) {
      case 'NotAvailable':
        return 'Biometric authentication is not available on this device.';
      case 'NotEnrolled':
        return 'No fingerprint or face data is enrolled on this device. Add one in your device settings first.';
      case 'LockedOut':
        return 'Too many attempts. Biometric authentication is temporarily locked.';
      case 'PermanentlyLockedOut':
        return 'Biometric authentication is locked. Please unlock your device with your PIN or password first.';
      case 'PasscodeNotSet':
        return 'Please set up a device PIN, pattern, or password before using biometrics.';
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
    final hash = await CryptoEngine.readSecure('master_hash');
    if (saltStr != null && hash != null) {
      final salt = base64.decode(saltStr);
      return CryptoEngine.deriveKey(hash, salt);
    }
    var biometricKey = await CryptoEngine.readSecure('biometric_key');
    if (biometricKey == null) {
      final newKey = CryptoEngine.generateSalt(32);
      await CryptoEngine.storeSecure('biometric_key', base64.encode(newKey));
      biometricKey = base64.encode(newKey);
    }
    return base64.decode(biometricKey);
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
    final data = _vault.map((e) => e.toJson()).toList();
    await CryptoEngine.storeSecure('vault_v2', jsonEncode(data));
  }

  Future<void> _loadVault() async {
    final data = await CryptoEngine.readSecure('vault_v2');
    if (data != null) {
      final list = jsonDecode(data) as List;
      _vault = list.map((j) => VaultEntry.fromJson(j as Map<String, dynamic>)).toList();
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
    if (data != null) {
      final list = jsonDecode(data) as List;
      _auditLog = list.map((j) => AuditEvent.fromJson(j as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _saveAuditLog() async {
    final data = _auditLog.map((e) => e.toJson()).toList();
    await CryptoEngine.storeSecure('audit_log', jsonEncode(data));
  }

  void _computeSecurityScore() {
    int score = 0;
    if (_hasMasterPassword) score += 20;
    if (_useBiometrics) score += 20;
    if (_vault.isNotEmpty) score += 15;
    final weakCount = weakPasswordCount;
    if (weakCount == 0 && _vault.isNotEmpty) score += 20;
    else if (weakCount < 3) score += 10;
    final dupCount = duplicatePasswordCount;
    if (dupCount == 0 && _vault.isNotEmpty) score += 15;
    else if (dupCount < 2) score += 7;
    score += min(10, _vault.length ~/ 2);
    _securityScore = score.clamp(0, 100);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// PARTICLE SYSTEM
// ════════════════════════════════════════════════════════════════════════════

class Particle {
  double x, y, vx, vy, size, life, maxLife, opacity;
  late Color color;
  bool isLine;

  Particle({required Random rng})
      : x = 0, y = 0, vx = 0, vy = 0, size = 0, life = 0, maxLife = 0,
        opacity = 0, isLine = false {
    reset(rng);
  }

  void reset(Random rng) {
    x = rng.nextDouble();
    y = rng.nextDouble();
    vx = (rng.nextDouble() - 0.5) * 0.0008;
    vy = (rng.nextDouble() - 0.5) * 0.0008 - 0.0003;
    size = rng.nextDouble() * 2.5 + 0.5;
    maxLife = rng.nextDouble() * 250 + 120;
    life = maxLife;
    isLine = rng.nextDouble() < 0.15;
    const colors = [kNeon, kPrimary, kSecondary, kAccent, kCyan];
    color = colors[rng.nextInt(colors.length)];
    opacity = rng.nextDouble() * 0.35 + 0.05;
  }

  void update() {
    x += vx;
    y += vy;
    life--;
    if (x < -0.1 || x > 1.1 || y < -0.1 || y > 1.1) life = 0;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (p.life / p.maxLife).clamp(0.0, 1.0);
      final fade = t < 0.2 ? t / 0.2 : t > 0.8 ? (1 - t) / 0.2 : 1.0;
      final alpha = (fade * p.opacity).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.5);
      canvas.drawCircle(Offset(p.x * size.width, p.y * size.height), p.size, paint);
      if (p.isLine) {
        final lp = Paint()
          ..color = p.color.withValues(alpha: (alpha * 0.3).clamp(0.0, 1.0))
          ..strokeWidth = 0.5;
        canvas.drawLine(
          Offset(p.x * size.width, p.y * size.height),
          Offset((p.x + p.vx * 30) * size.width, (p.y + p.vy * 30) * size.height),
          lp,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => true;
}

class ParticleSystem extends StatefulWidget {
  final Widget child;
  final int count;
  const ParticleSystem({super.key, required this.child, this.count = 50});

  @override
  State<ParticleSystem> createState() => _ParticleSystemState();
}

class _ParticleSystemState extends State<ParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat();
    for (int i = 0; i < widget.count; i++) {
      _particles.add(Particle(rng: _rng));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Positioned must be a direct child of Stack. RepaintBoundary now
    // wraps the CustomPaint/AnimatedBuilder *inside* Positioned.fill instead
    // of wrapping Positioned itself — this resolves the
    // "Incorrect use of ParentDataWidget" crash while still isolating the
    // particle repaint from the rest of the tree for performance.
    return Stack(children: [
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              for (final p in _particles) {
                p.update();
                if (p.life <= 0) p.reset(_rng);
              }
              return CustomPaint(painter: ParticlePainter(_particles));
            },
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class GridPainter extends CustomPainter {
  final double opacity;
  GridPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kNeon.withValues(alpha: opacity * 0.04)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ════════════════════════════════════════════════════════════════════════════
// SHARED PREMIUM WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool neonBorder;
  final VoidCallback? onTap;
  final double elevation;
  final Color? borderColor;
  final List<Color>? gradientColors;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 18,
    this.neonBorder = true,
    this.onTap,
    this.elevation = 1,
    this.borderColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors!,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight)
            : const LinearGradient(
                colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        border: Border.all(
          color: borderColor ?? (neonBorder ? kGlassBorder : Colors.transparent),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
              color: kPrimary.withValues(alpha: (0.06 * elevation).clamp(0.0, 1.0)),
              blurRadius: (24 * elevation).clamp(0.0, double.infinity),
              spreadRadius: 0),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              spreadRadius: 0),
        ],
      ),
      child: child,
    );
    if (onTap != null) {
      return _PressEffect(onTap: onTap!, child: card);
    }
    return card;
  }
}

class _PressEffect extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _PressEffect({required this.child, required this.onTap});

  @override
  State<_PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<_PressEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

class NeonText extends StatelessWidget {
  final String text;
  final double? fontSize;
  final FontWeight fontWeight;
  final Color color;
  final double? letterSpacing;
  final TextAlign? textAlign;
  final bool gradient;

  const NeonText(
    this.text, {
    super.key,
    this.fontSize,
    this.fontWeight = FontWeight.w600,
    this.color = kNeon,
    this.letterSpacing,
    this.textAlign,
    this.gradient = false,
  });

  @override
  Widget build(BuildContext context) {
    if (gradient) {
      return ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [kNeon, kCyan],
        ).createShader(bounds),
        child: Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: kText,
            letterSpacing: letterSpacing,
          ),
        ),
      );
    }
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        shadows: [
          Shadow(color: color.withValues(alpha: 0.7), blurRadius: 14),
          Shadow(color: color.withValues(alpha: 0.3), blurRadius: 28),
        ],
      ),
    );
  }
}

class CyberButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final List<Color>? gradient;
  final IconData? icon;
  final bool outlined;
  final double? width;
  final double height;
  final double fontSize;

  const CyberButton({
    super.key,
    required this.label,
    this.onPressed,
    this.gradient,
    this.icon,
    this.outlined = false,
    this.width,
    this.height = 52,
    this.fontSize = 13,
  });

  @override
  State<CyberButton> createState() => _CyberButtonState();
}

class _CyberButtonState extends State<CyberButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _glow = Tween<double>(begin: 1.0, end: 0.4).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grad = widget.gradient ?? AppColors.gradientPrimary;
    final enabled = widget.onPressed != null;
    return GestureDetector(
      onTapDown: enabled
          ? (_) => _ctrl.forward()
          : null,
      onTapUp: enabled
          ? (_) {
              _ctrl.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: enabled ? () => _ctrl.reverse() : null,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => ScaleTransition(
          scale: _scale,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: widget.outlined
                    ? null
                    : LinearGradient(
                        colors: grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                border: widget.outlined
                    ? Border.all(color: kNeon, width: 1.5)
                    : Border.all(color: grad.first.withValues(alpha: 0.4), width: 1),
                boxShadow: !enabled
                    ? []
                    : [
                        BoxShadow(
                            color: grad.first.withValues(alpha: 0.45 * _glow.value),
                            blurRadius: 24,
                            spreadRadius: 0),
                        BoxShadow(
                            color: grad.last.withValues(alpha: 0.2 * _glow.value),
                            blurRadius: 48,
                            spreadRadius: 0),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: widget.outlined ? kNeon : kText, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.outlined ? kNeon : kText,
                        fontWeight: FontWeight.w800,
                        fontSize: widget.fontSize,
                        letterSpacing: 1.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CyberTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final int? maxLines;

  const CyberTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGlassBorder),
        gradient: const LinearGradient(
            colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        enabled: enabled,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        maxLines: obscure ? 1 : maxLines,
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: kNeon, size: 20)
              : null,
          suffix: suffix,
        ),
      ),
    );
  }
}

class SkeletonLoader extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const SkeletonLoader(
      {super.key,
      required this.width,
      required this.height,
      this.radius = 8});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.04, end: 0.15).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: kNeon.withValues(alpha: _anim.value),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ROOT APP
// ════════════════════════════════════════════════════════════════════════════

class CipherGuardApp extends StatefulWidget {
  const CipherGuardApp({super.key});

  @override
  State<CipherGuardApp> createState() => _CipherGuardAppState();
}

class _CipherGuardAppState extends State<CipherGuardApp> {
  final AppState _appState = AppState();

  @override
  void initState() {
    super.initState();
    _appState.initialize();
  }

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) => MaterialApp(
        title: 'CipherGuard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: _buildRoot(),
      ),
    );
  }

  Widget _buildRoot() {
    if (!_appState.initialized) return const SplashScreen();
    if (!_appState.profileComplete) {
      return UserRegistrationScreen(appState: _appState);
    }
    if (!_appState.hasMasterPassword && !_appState.useBiometrics) {
      return OnboardingScreen(appState: _appState);
    }
    if (!_appState.authenticated) return AuthScreen(appState: _appState);
    return MainShell(appState: _appState);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))
      ..forward();
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
    _progressAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _progressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.2,
            colors: [Color(0xFF1A0A2E), Color(0xFF050505)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AnimatedBuilder(
              animation: Listenable.merge([_pulseAnim, _rotateAnim, _progressAnim]),
              builder: (_, __) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: _rotateAnim.value * 2 * pi,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: kNeon.withValues(alpha: 0.15), width: 1),
                        ),
                      ),
                    ),
                    Transform.rotate(
                      angle: -_rotateAnim.value * 2 * pi * 0.7,
                      child: Container(
                        width: 115,
                        height: 115,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: kPrimary.withValues(alpha: 0.3), width: 1.5),
                        ),
                      ),
                    ),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          kAccent.withValues(alpha: 0.4),
                          Colors.transparent
                        ]),
                        boxShadow: [
                          BoxShadow(
                              color: kPrimary.withValues(alpha: 0.5 * _pulseAnim.value),
                              blurRadius: 50,
                              spreadRadius: 10),
                          BoxShadow(
                              color: kNeon.withValues(alpha: 0.2 * _pulseAnim.value),
                              blurRadius: 80,
                              spreadRadius: 20),
                        ],
                        border: Border.all(
                            color: kNeon.withValues(alpha: _pulseAnim.value * 0.7),
                            width: 2),
                      ),
                      child: Icon(Icons.shield_rounded,
                          color: kNeon.withValues(alpha: _pulseAnim.value),
                          size: 44),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                ShaderMask(
                  shaderCallback: (b) => const LinearGradient(
                    colors: [kNeon, kCyan, kNeon],
                    stops: [0, 0.5, 1],
                  ).createShader(b),
                  child: const Text(
                    'CIPHERGUARD',
                    style: TextStyle(
                      color: kText,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 10,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text('SECURITY SUITE v3.0',
                    style: TextStyle(color: kTextDim, fontSize: 10, letterSpacing: 5)),
                const SizedBox(height: 48),
                SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _progressAnim.value,
                          backgroundColor: kSurface2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              kNeon.withValues(alpha: _pulseAnim.value * 0.8 + 0.2)),
                          minHeight: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('INITIALIZING SECURITY CORE',
                          style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ONBOARDING SCREEN
// ════════════════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  final AppState appState;
  const OnboardingScreen({super.key, required this.appState});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _floatAnim;
  int _selectedCard = -1;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _fadeIn = CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideUp = Tween<double>(begin: 50, end: 0).animate(
        CurvedAnimation(
            parent: _entryCtrl,
            curve: const Interval(0.2, 0.9, curve: Curves.easeOut)));
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter(1.0))),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.5),
                  radius: 1.0,
                  colors: [Color(0xFF1A0030), Color(0xFF050505)],
                ),
              ),
            ),
          ),
          ParticleSystem(child: const SizedBox.expand()),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeIn, _floatAnim]),
              builder: (_, __) => FadeTransition(
                opacity: _fadeIn,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 36),
                        Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: _buildLogo(),
                        ),
                        const SizedBox(height: 40),
                        NeonText(
                          'CHOOSE YOUR\nPROTECTION',
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3,
                          textAlign: TextAlign.center,
                          color: kText,
                          gradient: true,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SELECT YOUR PRIMARY AUTHENTICATION METHOD',
                          style: TextStyle(
                              color: kTextDim, fontSize: 10, letterSpacing: 3),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        Expanded(
                          child: _buildCards(),
                        ),
                        const SizedBox(height: 20),
                        if (_selectedCard >= 0)
                          CyberButton(
                            label: 'INITIALIZE CIPHERGUARD',
                            onPressed: _proceed,
                            width: double.infinity,
                            gradient: AppColors.gradientNeon,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(color: kPrimary.withValues(alpha: 0.6), blurRadius: 30, spreadRadius: 4),
              BoxShadow(color: kNeon.withValues(alpha: 0.2), blurRadius: 60, spreadRadius: 8),
            ],
          ),
          child: const Icon(Icons.shield_rounded, color: kText, size: 34),
        ),
        const SizedBox(height: 14),
        NeonText('CIPHERGUARD',
            fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 6, gradient: true),
        Text('SECURITY SUITE v3.0',
            style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 5)),
      ],
    );
  }

  Widget _buildCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cards = [
          _buildAuthCard(
            0,
            Icons.fingerprint,
            'BIOMETRIC',
            'AUTHENTICATION',
            ['Face ID / Touch ID', 'Fingerprint sensor', 'Hardware-backed TEE', 'Instant access'],
            AppColors.gradientPrimary,
          ),
          _buildAuthCard(
            1,
            Icons.lock_rounded,
            'MASTER',
            'PASSWORD',
            ['AES-256-GCM vault', 'Zero-knowledge design', 'Offline protection', 'Recovery support'],
            AppColors.gradientSecondary,
          ),
        ];
        if (isWide) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(height: 14),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }

  Widget _buildAuthCard(int index, IconData icon, String title, String subtitle,
      List<String> features, List<Color> grad) {
    final isSelected = _selectedCard == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedCard = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isSelected
              ? LinearGradient(
                  colors: grad.map((c) => c.withValues(alpha: 0.2)).toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : const LinearGradient(
                  colors: [Color(0x0CFFFFFF), Color(0x06FFFFFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
          border: Border.all(
            color: isSelected ? grad.first : kGlassBorder2,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: grad.first.withValues(alpha: 0.45),
                      blurRadius: 40,
                      spreadRadius: 0),
                  BoxShadow(
                      color: grad.last.withValues(alpha: 0.2),
                      blurRadius: 80,
                      spreadRadius: 0),
                ]
              : [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 16,
                      spreadRadius: 0)
                ],
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                        colors: grad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    boxShadow: isSelected
                        ? [BoxShadow(color: grad.first.withValues(alpha: 0.5), blurRadius: 20)]
                        : [],
                  ),
                  child: Icon(icon, color: kText, size: 28),
                ),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? grad.first : Colors.transparent,
                    border: Border.all(
                        color: isSelected ? grad.first : kGlassBorder, width: 2),
                    boxShadow: isSelected
                        ? [BoxShadow(color: grad.first.withValues(alpha: 0.5), blurRadius: 12)]
                        : [],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: kText, size: 16)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            NeonText(title,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
                color: isSelected ? grad.first : kText),
            Text(subtitle,
                style: TextStyle(
                    color: isSelected ? grad.last : kTextDim,
                    fontSize: 11,
                    letterSpacing: 2)),
            const SizedBox(height: 14),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? grad.first : kTextMuted,
                          boxShadow: isSelected
                              ? [BoxShadow(color: grad.first, blurRadius: 6)]
                              : [],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f,
                            style: TextStyle(
                                color: isSelected
                                    ? kText.withValues(alpha: 0.85)
                                    : kTextDim,
                                fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                )),
          ],
          ),
        ),
      ),
    );
  }

  void _proceed() {
    if (_selectedCard == 0) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _BiometricSetupSheet(appState: widget.appState),
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _MasterPasswordSetupSheet(appState: widget.appState),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BIOMETRIC SETUP SHEET
// ════════════════════════════════════════════════════════════════════════════

class _BiometricSetupSheet extends StatefulWidget {
  final AppState appState;
  const _BiometricSetupSheet({required this.appState});

  @override
  State<_BiometricSetupSheet> createState() => _BiometricSetupSheetState();
}

class _BiometricSetupSheetState extends State<_BiometricSetupSheet>
    with TickerProviderStateMixin {
  late AnimationController _scanCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _scanAnim;
  late Animation<double> _pulseAnim;
  bool _loading = false;
  String _status = 'TAP TO SCAN YOUR BIOMETRICS';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
          ..repeat(reverse: true);
    _scanAnim = Tween<double>(begin: 0, end: 1).animate(_scanCtrl);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    setState(() {
      _loading = true;
      _status = 'REQUESTING BIOMETRIC ACCESS...';
      _errorMessage = null;
    });
    final success = await widget.appState.setupBiometrics();
    if (!mounted) return;
    if (success) {
      setState(() => _status = 'BIOMETRICS REGISTERED');
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context);
    } else {
      setState(() {
        _loading = false;
        _status = 'TAP TO SCAN YOUR BIOMETRICS';
        _errorMessage = widget.appState.lastBiometricError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 28,
          left: 28,
          right: 28,
        ),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2), color: kGlassBorder)),
          const SizedBox(height: 28),
          AnimatedBuilder(
            animation: Listenable.merge([_scanAnim, _pulseAnim]),
            builder: (_, __) => Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kNeon.withValues(alpha: 0.15 * _pulseAnim.value),
                        width: 1),
                  ),
                ),
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kPrimary.withValues(alpha: 0.3 * _pulseAnim.value),
                        width: 1.5),
                  ),
                ),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      kAccent.withValues(alpha: 0.3 * _pulseAnim.value),
                      Colors.transparent
                    ]),
                    border: Border.all(
                        color: kNeon.withValues(alpha: 0.5 * _pulseAnim.value),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: kPrimary.withValues(alpha: 0.4 * _pulseAnim.value),
                          blurRadius: 30,
                          spreadRadius: 5),
                    ],
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: kNeon, strokeWidth: 2)
                      : Icon(Icons.fingerprint,
                          color: kNeon.withValues(alpha: _pulseAnim.value), size: 44),
                ),
                if (!_loading)
                  Positioned(
                    top: 0,
                    child: Transform.translate(
                      offset: Offset(0, _scanAnim.value * 130 - 5),
                      child: Container(
                        width: 100,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            kNeon.withValues(alpha: 0.8),
                            Colors.transparent
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          NeonText('BIOMETRIC SETUP', fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4),
          const SizedBox(height: 8),
          Text(_status,
              style: const TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 2),
              textAlign: TextAlign.center),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: kError.withValues(alpha: 0.08),
                border: Border.all(color: kError.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: kError, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: kError, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          _bioFeatureRow(Icons.face_retouching_natural_rounded, 'Face Recognition',
              'AI-powered facial authentication'),
          const SizedBox(height: 10),
          _bioFeatureRow(
              Icons.fingerprint, 'Fingerprint Sensor', 'Hardware-secured fingerprint scan'),
          const SizedBox(height: 10),
          _bioFeatureRow(Icons.shield_rounded, 'Hardware Backed',
              'Stored in secure enclave / TEE'),
          const SizedBox(height: 28),
          CyberButton(
            label: _loading ? 'SCANNING...' : 'ACTIVATE BIOMETRICS',
            icon: _loading ? null : Icons.fingerprint,
            onPressed: _loading ? null : _activate,
            width: double.infinity,
          ),
          const SizedBox(height: 12),
          CyberButton(
            label: 'CANCEL',
            onPressed: () => Navigator.pop(context),
            outlined: true,
            width: double.infinity,
          ),
        ],
        ),
      ),
    );
  }

  Widget _bioFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: kPrimary.withValues(alpha: 0.12)),
          child: Icon(icon, color: kNeon, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: kTextDim, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MASTER PASSWORD SETUP SHEET
// ════════════════════════════════════════════════════════════════════════════

class _MasterPasswordSetupSheet extends StatefulWidget {
  final AppState appState;
  const _MasterPasswordSetupSheet({required this.appState});

  @override
  State<_MasterPasswordSetupSheet> createState() =>
      _MasterPasswordSetupSheetState();
}

class _MasterPasswordSetupSheetState extends State<_MasterPasswordSetupSheet> {
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  bool _obs1 = true;
  bool _obs2 = true;
  String? _error;
  int _strength = 0;

  @override
  void dispose() {
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 28,
        left: 28,
        right: 28,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: kGlassBorder)),
            ),
            const SizedBox(height: 28),
            const Center(
                child: NeonText('MASTER PASSWORD',
                    fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4)),
            const SizedBox(height: 6),
            const Center(
                child: Text('Create your zero-knowledge vault password',
                    style: TextStyle(color: kTextDim, fontSize: 12),
                    textAlign: TextAlign.center)),
            const SizedBox(height: 28),
            _pwField('Master Password', _pw1, _obs1, (v) => setState(() => _obs1 = v),
                onChanged: (v) => setState(() => _strength = CryptoEngine.analyzePasswordStrength(v))),
            const SizedBox(height: 10),
            _strengthBar(),
            const SizedBox(height: 14),
            _pwField('Confirm Password', _pw2, _obs2, (v) => setState(() => _obs2 = v)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _errorBox(_error!),
            ],
            const SizedBox(height: 24),
            CyberButton(
                label: 'CREATE VAULT',
                icon: Icons.lock_rounded,
                onPressed: _submit,
                width: double.infinity),
            const SizedBox(height: 12),
            CyberButton(
                label: 'CANCEL',
                onPressed: () => Navigator.pop(context),
                outlined: true,
                width: double.infinity),
          ],
        ),
      ),
    );
  }

  Widget _pwField(String label, TextEditingController ctrl, bool obs,
      Function(bool) onToggle,
      {Function(String)? onChanged}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGlassBorder),
        gradient: const LinearGradient(colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obs,
        onChanged: onChanged,
        style: const TextStyle(color: kText, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextDim, fontSize: 12, letterSpacing: 1),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: kNeon, size: 20),
          suffixIcon: IconButton(
            icon: Icon(obs ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: kTextDim, size: 20),
            onPressed: () => onToggle(!obs),
          ),
        ),
      ),
    );
  }

  Widget _strengthBar() {
    final color = CryptoEngine.strengthColor(_strength);
    final label = CryptoEngine.strengthLabel(_strength);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PASSWORD STRENGTH',
                style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 2)),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _strength / 100,
            backgroundColor: kSurface2,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: kError.withValues(alpha: 0.1),
        border: Border.all(color: kError.withValues(alpha: 0.3)),
      ),
      child: Text(msg, style: const TextStyle(color: kError, fontSize: 12)),
    );
  }

  void _submit() {
    setState(() => _error = null);
    if (_pw1.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_pw1.text != _pw2.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    Navigator.pop(context);
    widget.appState.setupMasterPassword(_pw1.text);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// AUTH SCREEN
// ════════════════════════════════════════════════════════════════════════════

class AuthScreen extends StatefulWidget {
  final AppState appState;
  const AuthScreen({super.key, required this.appState});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _rotateCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _rotateAnim;
  final TextEditingController _pwCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
    if (widget.appState.useBiometrics) {
      Future.delayed(const Duration(milliseconds: 600), _tryBiometrics);
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await widget.appState.authenticateWithBiometrics();
    if (!success && mounted) {
      setState(() {
        _loading = false;
        _error = widget.appState.lastBiometricError ?? 'Biometric authentication failed. Try again.';
      });
    }
  }

  Future<void> _submitPassword() async {
    if (widget.appState.isLockedOut) {
      setState(() => _error = 'Too many failed attempts. Wait 5 minutes.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final success = await widget.appState.authenticateWithPassword(_pwCtrl.text);
    if (!success && mounted) {
      setState(() {
        _loading = false;
        _error = widget.appState.isLockedOut
            ? 'Account locked due to too many failed attempts.'
            : 'Invalid master password (${widget.appState.failedAttempts}/5 attempts)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter(0.8))),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2),
                  radius: 1.1,
                  colors: [Color(0xFF1A0030), Color(0xFF050505)],
                ),
              ),
            ),
          ),
          ParticleSystem(child: const SizedBox.expand(), count: 30),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: AnimatedBuilder(
                  animation: Listenable.merge([_pulseAnim, _rotateAnim]),
                  builder: (_, __) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildShield(),
                      const SizedBox(height: 32),
                      NeonText('CIPHERGUARD',
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          gradient: true),
                      const SizedBox(height: 6),
                      Text('AUTHENTICATION REQUIRED',
                          style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 4)),
                      const SizedBox(height: 44),
                      if (widget.appState.useBiometrics) ...[
                        GlassCard(
                          onTap: _tryBiometrics,
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                      colors: AppColors.gradientPrimary),
                                  boxShadow: [
                                    BoxShadow(
                                        color: kPrimary.withValues(alpha: 0.5),
                                        blurRadius: 16)
                                  ],
                                ),
                                child: const Icon(Icons.fingerprint,
                                    color: kText, size: 26),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('BIOMETRIC UNLOCK',
                                        style: TextStyle(
                                            color: kText,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2,
                                            fontSize: 13)),
                                    SizedBox(height: 2),
                                    Text('Touch ID · Face ID · Fingerprint',
                                        style: TextStyle(color: kTextDim, fontSize: 11)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  color: kNeon.withValues(alpha: 0.6)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider(color: kGlassBorder2)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR',
                                  style: TextStyle(
                                      color: kTextMuted, fontSize: 10, letterSpacing: 3)),
                            ),
                            const Expanded(child: Divider(color: kGlassBorder2)),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kGlassBorder),
                          gradient: const LinearGradient(
                              colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
                        ),
                        child: TextField(
                          controller: _pwCtrl,
                          obscureText: _obscure,
                          style: const TextStyle(color: kText),
                          onSubmitted: (_) => _submitPassword(),
                          decoration: InputDecoration(
                            labelText: 'Master Password',
                            labelStyle: const TextStyle(
                                color: kTextDim, letterSpacing: 1, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(18),
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: kNeon),
                            suffixIcon: IconButton(
                              icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: kTextDim,
                                  size: 20),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: kError.withValues(alpha: 0.08),
                            border:
                                Border.all(color: kError.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: kError, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: kError, fontSize: 12))),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      CyberButton(
                        label: _loading ? 'AUTHENTICATING...' : 'UNLOCK VAULT',
                        icon: _loading ? null : Icons.lock_open_rounded,
                        onPressed: _loading ? null : _submitPassword,
                        width: double.infinity,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShield() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: _rotateAnim.value * 2 * pi,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kNeon.withValues(alpha: 0.1), width: 1),
            ),
          ),
        ),
        Transform.rotate(
          angle: -_rotateAnim.value * 2 * pi * 0.6,
          child: Container(
            width: 122,
            height: 122,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kPrimary.withValues(alpha: 0.25), width: 1.5),
            ),
          ),
        ),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [kAccent.withValues(alpha: 0.35), Colors.transparent]),
            border: Border.all(color: kNeon.withValues(alpha: _pulseAnim.value * 0.7), width: 2),
            boxShadow: [
              BoxShadow(
                  color: kPrimary.withValues(alpha: 0.55 * _pulseAnim.value),
                  blurRadius: 50,
                  spreadRadius: 8),
              BoxShadow(
                  color: kNeon.withValues(alpha: 0.2 * _pulseAnim.value),
                  blurRadius: 80,
                  spreadRadius: 16),
            ],
          ),
          child: _loading
              ? const CircularProgressIndicator(color: kNeon, strokeWidth: 2)
              : Icon(Icons.shield_rounded,
                  color: kNeon.withValues(alpha: _pulseAnim.value), size: 50),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MAIN SHELL + FLOATING NAV
// ════════════════════════════════════════════════════════════════════════════

class MainShell extends StatelessWidget {
  final AppState appState;
  const MainShell({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (_, __) => Scaffold(
        backgroundColor: kBg,
        body: Stack(
          children: [
            Positioned.fill(child: _buildContent()),
            Positioned(
                left: 0, right: 0, bottom: 0, child: _FloatingNavBar(appState: appState)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (appState.activeTab) {
      case 0: return DashboardPage(appState: appState);
      case 1: return VaultPage(appState: appState);
      case 2: return SecurityCenterPage(appState: appState);
      case 3: return InfoPage(appState: appState);
      default: return DashboardPage(appState: appState);
    }
  }
}

class _FloatingNavBar extends StatefulWidget {
  final AppState appState;
  const _FloatingNavBar({required this.appState});

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _floatAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: kSurface.withValues(alpha: 0.97),
              border: Border.all(color: kGlassBorder),
              boxShadow: [
                BoxShadow(color: kPrimary.withValues(alpha: 0.2), blurRadius: 32, spreadRadius: 0),
                BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 0),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(child: Center(child: _navItem(0, Icons.dashboard_rounded, widget.appState.tr('dashboard').toUpperCase()))),
                Expanded(child: Center(child: _navItem(1, Icons.key_rounded, widget.appState.tr('vault').toUpperCase()))),
                Expanded(child: Center(child: _navItem(2, Icons.security_rounded, widget.appState.tr('security').toUpperCase()))),
                Expanded(child: Center(child: _navItem(3, Icons.person_rounded, widget.appState.tr('info').toUpperCase()))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = widget.appState.activeTab == index;
    return GestureDetector(
      onTap: () => widget.appState.setActiveTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        // FIX: Curves.easeOutBack overshoots past t=1.0. AnimatedContainer
        // uses that t to lerp BoxDecoration.boxShadow; when the list toggles
        // between empty and non-empty, BoxShadow.lerp falls back to
        // `shadow.scale(1.0 - t)`, and an overshot t > 1 makes that scale
        // negative — producing a negative blurRadius and the runtime
        // assertion "Text shadow blur radius should be non-negative."
        // easeOutCubic never exceeds [0, 1], so it's safe here.
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isActive
              ? const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : null,
          // FIX: keep the list length constant (2 items) in both states
          // instead of toggling to `[]`. This makes BoxDecoration.lerp pair
          // shadows directly instead of going through the null/scale path,
          // which is the other half of the negative-blurRadius fix above.
          boxShadow: isActive
              ? [
                  BoxShadow(color: kPrimary.withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 0),
                  BoxShadow(color: kNeon.withValues(alpha: 0.2), blurRadius: 40, spreadRadius: 0),
                ]
              : [
                  BoxShadow(color: kPrimary.withValues(alpha: 0.0), blurRadius: 0, spreadRadius: 0),
                  BoxShadow(color: kNeon.withValues(alpha: 0.0), blurRadius: 0, spreadRadius: 0),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? kText : kTextDim, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? kText : kTextMuted,
                fontSize: 7,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE
// ════════════════════════════════════════════════════════════════════════════

class DashboardPage extends StatefulWidget {
  final AppState appState;
  const DashboardPage({super.key, required this.appState});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryCtrl;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _entryCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
          ..forward();
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(as)),
            SliverToBoxAdapter(child: _buildSecurityScore(as)),
            SliverToBoxAdapter(child: _buildStatsRow(as)),
            SliverToBoxAdapter(child: _buildHealthCards(as)),
            SliverToBoxAdapter(child: _buildCategoryBreakdown(as)),
            SliverToBoxAdapter(child: _buildRecentActivity(as)),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppState as) {
    final greeting = as.fullName.isNotEmpty ? '${as.tr('greeting')}, ${as.fullName.split(' ').first}' : as.tr('greeting');
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(as.tr('security_overview'),
                    style: TextStyle(
                        color: kTextMuted, fontSize: 10, letterSpacing: 3)),
                const SizedBox(height: 4),
                NeonText(greeting,
                    fontSize: 26, fontWeight: FontWeight.w900, gradient: true),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => as.lock(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: kError.withValues(alpha: 0.1),
                border: Border.all(color: kError.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.lock_rounded, color: kError, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityScore(AppState as) {
    final score = as.securityScore;
    final color = score >= 80
        ? kSuccess
        : score >= 50
            ? kWarning
            : kError;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(24),
        gradientColors: [color.withValues(alpha: 0.08), kSurface2.withValues(alpha: 0.5)],
        borderColor: color.withValues(alpha: 0.3),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    backgroundColor: kSurface3,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeWidth: 5,
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SECURITY SCORE',
                      style: TextStyle(
                          color: kTextMuted, fontSize: 10, letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    score >= 80
                        ? 'EXCELLENT'
                        : score >= 60
                            ? 'GOOD'
                            : score >= 40
                                ? 'MODERATE'
                                : 'AT RISK',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${as.vault.length} items protected',
                    style: const TextStyle(color: kTextDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(AppState as) {
    final favoriteCount = as.vault.where((e) => e.isFavorite).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
              child: _statCard(
                  '${as.vault.length}', 'VAULT\nITEMS', Icons.key_rounded,
                  AppColors.gradientPrimary)),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(
                  '$favoriteCount', 'FAVORITE\nITEMS', Icons.star_rounded,
                  AppColors.gradientGold)),
          const SizedBox(width: 12),
          Expanded(
              child: _statCard(
                  '${as.weakPasswordCount}', 'WEAK\nPASSWORDS', Icons.warning_rounded,
                  as.weakPasswordCount > 0
                      ? AppColors.gradientFire
                      : AppColors.gradientSuccess)),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon, List<Color> grad) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: grad.first.withValues(alpha: 0.25),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(colors: grad),
            ),
            child: Icon(icon, color: kText, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: grad.first,
                  fontWeight: FontWeight.w900,
                  fontSize: 24)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  color: kTextDim, fontSize: 9, letterSpacing: 1),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildHealthCards(AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VAULT HEALTH',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          _healthRow(
            Icons.content_copy_rounded,
            'Duplicate Passwords',
            '${as.duplicatePasswordCount} found',
            as.duplicatePasswordCount > 0 ? kError : kSuccess,
          ),
          const SizedBox(height: 8),
          _healthRow(
            Icons.lock_open_rounded,
            'Weak Passwords',
            '${as.weakPasswordCount} need attention',
            as.weakPasswordCount > 0 ? kWarning : kSuccess,
          ),
          const SizedBox(height: 8),
          _healthRow(
            as.useBiometrics || as.hasMasterPassword
                ? Icons.verified_rounded
                : Icons.error_rounded,
            'Authentication',
            as.useBiometrics
                ? 'Biometric enabled'
                : as.hasMasterPassword
                    ? 'Master password set'
                    : 'Not configured',
            as.useBiometrics || as.hasMasterPassword ? kSuccess : kError,
          ),
        ],
      ),
    );
  }

  Widget _healthRow(IconData icon, String title, String status, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderColor: color.withValues(alpha: 0.2),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(status,
                    style: TextStyle(color: color, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: kTextMuted.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(AppState as) {
    final breakdown = as.categoryBreakdown;
    if (breakdown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CATEGORY BREAKDOWN',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: breakdown.entries.map((e) {
              final grad = e.key.gradient;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                      colors: grad.map((c) => c.withValues(alpha: 0.15)).toList()),
                  border: Border.all(color: grad.first.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.key.icon, color: grad.first, size: 14),
                    const SizedBox(width: 6),
                    Text('${e.key.label}  ${e.value}',
                        style: TextStyle(
                            color: grad.first,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(AppState as) {
    final events = as.auditLog.take(5).toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('RECENT ACTIVITY',
              style: TextStyle(
                  color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: events.map((e) {
                final color = e.action == 'AUTH'
                    ? kCyan
                    : e.action == 'SECURITY'
                        ? kError
                        : e.action == 'FILES'
                            ? kWarning
                            : kNeon;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(color: color, blurRadius: 8)
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.detail,
                                style: const TextStyle(
                                    color: kText, fontSize: 12)),
                            Text(
                              _formatTime(e.timestamp),
                              style: const TextStyle(
                                  color: kTextMuted, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: color.withValues(alpha: 0.12),
                        ),
                        child: Text(e.action,
                            style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// VAULT PAGE
// ════════════════════════════════════════════════════════════════════════════

class VaultPage extends StatefulWidget {
  final AppState appState;
  const VaultPage({super.key, required this.appState});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final as = widget.appState;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: as,
        builder: (_, __) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(as)),
            SliverToBoxAdapter(child: _buildSearch(as)),
            SliverToBoxAdapter(child: _buildCategoryFilter(as)),
            as.filteredVault.isEmpty
                ? SliverToBoxAdapter(child: _buildEmpty())
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _buildVaultItem(as.filteredVault[i], as),
                      childCount: as.filteredVault.length,
                    ),
                  ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: FloatingActionButton.extended(
          onPressed: () => _openAddEntry(context, as),
          backgroundColor: kPrimary,
          foregroundColor: kText,
          icon: const Icon(Icons.add_rounded),
          label: const Text('ADD ITEM',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
        ),
      ),
    );
  }

  Widget _buildHeader(AppState as) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${as.vault.length} ITEMS',
              style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 4),
          const NeonText('Vault', fontSize: 28, fontWeight: FontWeight.w900, gradient: true),
        ],
      ),
    );
  }

  Widget _buildSearch(AppState as) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGlassBorder),
          color: kSurface2,
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => as.setSearch(v),
          style: const TextStyle(color: kText),
          decoration: InputDecoration(
            hintText: 'Search vault...',
            hintStyle: const TextStyle(color: kTextMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: kNeon),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: kTextDim),
                    onPressed: () {
                      _searchCtrl.clear();
                      as.setSearch('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(AppState as) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _filterChip('ALL', null, as),
          ...VaultItemCategory.values.map((c) => _filterChip(c.label, c, as)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, VaultItemCategory? cat, AppState as) {
    final isActive = as.filterCategory == cat;
    return GestureDetector(
      onTap: () => as.setFilterCategory(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isActive
              ? const LinearGradient(colors: AppColors.gradientPrimary)
              : null,
          border: Border.all(color: isActive ? kPrimary : kGlassBorder2),
          color: isActive ? null : kSurface2,
        ),
        child: Text(
          label,
          style: TextStyle(
              color: isActive ? kText : kTextDim,
              fontSize: 11,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.key_off_rounded, size: 64, color: kTextMuted.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('Your vault is empty',
              style: TextStyle(color: kTextDim, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Tap + to add your first secure item',
              style: TextStyle(color: kTextMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVaultItem(VaultEntry entry, AppState as) {
    final grad = entry.category.gradient;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderColor: grad.first.withValues(alpha: 0.2),
        onTap: () => _openDetail(context, entry, as),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: LinearGradient(colors: grad),
                boxShadow: [
                  BoxShadow(color: grad.first.withValues(alpha: 0.4), blurRadius: 12)
                ],
              ),
              child: Icon(entry.category.icon, color: kText, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.title,
                          style: const TextStyle(
                              color: kText, fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (entry.isFavorite)
                        const Icon(Icons.star_rounded, color: kWarning, size: 14),
                    ],
                  ),
                  if (entry.username.isNotEmpty)
                    Text(entry.username,
                        style: const TextStyle(color: kTextDim, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  if (entry.category == VaultItemCategory.login) ...[
                    const SizedBox(height: 4),
                    _strengthPill(entry.strengthScore),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(entry.category.label,
                  style: TextStyle(color: grad.first, fontSize: 10, fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  textAlign: TextAlign.right),
            ),
          ],
        ),
      ),
    );
  }

  Widget _strengthPill(int score) {
    final color = CryptoEngine.strengthColor(score);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        CryptoEngine.strengthLabel(score),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1),
      ),
    );
  }

  void _openAddEntry(BuildContext context, AppState as) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddEditVaultSheet(appState: as),
    );
  }

  void _openDetail(BuildContext context, VaultEntry entry, AppState as) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VaultDetailSheet(entry: entry, appState: as),
    );
  }
}

class _AddEditVaultSheet extends StatefulWidget {
  final AppState appState;
  final VaultEntry? entry;
  const _AddEditVaultSheet({required this.appState, this.entry});

  @override
  State<_AddEditVaultSheet> createState() => _AddEditVaultSheetState();
}

class _AddEditVaultSheetState extends State<_AddEditVaultSheet> {
  final _titleCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  VaultItemCategory _category = VaultItemCategory.login;
  bool _obscure = true;
  int _strength = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final e = widget.entry!;
      _titleCtrl.text = e.title;
      _userCtrl.text = e.username;
      _websiteCtrl.text = e.website ?? '';
      _notesCtrl.text = e.notes ?? '';
      _category = e.category;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _userCtrl.dispose();
    _secretCtrl.dispose();
    _websiteCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty || _secretCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    if (widget.entry == null) {
      await widget.appState.addVaultEntry(VaultEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text,
        username: _userCtrl.text,
        rawSecret: _secretCtrl.text,
        category: _category,
        website: _websiteCtrl.text.isEmpty ? null : _websiteCtrl.text,
        notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        createdAt: DateTime.now(),
      ));
    } else {
      final updated = widget.entry!
        ..title = _titleCtrl.text
        ..username = _userCtrl.text
        ..rawSecret = _secretCtrl.text
        ..category = _category
        ..website = _websiteCtrl.text.isEmpty ? null : _websiteCtrl.text
        ..notes = _notesCtrl.text.isEmpty ? null : _notesCtrl.text;
      await widget.appState.updateVaultEntry(updated);
    }
    if (mounted) Navigator.pop(context);
  }

  void _generatePassword() {
    final pwd = CryptoEngine.generateStrongPassword();
    _secretCtrl.text = pwd;
    setState(() {
      _strength = CryptoEngine.analyzePasswordStrength(pwd);
      _obscure = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 28,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: kGlassBorder)),
            ),
            const SizedBox(height: 20),
            Center(
              child: NeonText(
                widget.entry == null ? 'ADD VAULT ITEM' : 'EDIT ITEM',
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text('CATEGORY', style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 2)),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: VaultItemCategory.values.map((c) {
                  final isSelected = _category == c;
                  final grad = c.gradient;
                  return GestureDetector(
                    onTap: () => setState(() => _category = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: isSelected
                            ? LinearGradient(colors: grad)
                            : null,
                        border: Border.all(
                            color: isSelected ? grad.first : kGlassBorder2),
                        color: isSelected ? null : kSurface2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon,
                              color: isSelected ? kText : kTextDim, size: 14),
                          const SizedBox(width: 6),
                          Text(c.label,
                              style: TextStyle(
                                  color: isSelected ? kText : kTextDim,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            CyberTextField(
                controller: _titleCtrl,
                label: 'Title *',
                prefixIcon: Icons.label_rounded),
            const SizedBox(height: 10),
            CyberTextField(
                controller: _userCtrl,
                label: 'Username / Email',
                prefixIcon: Icons.person_rounded),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kGlassBorder),
                gradient: const LinearGradient(
                    colors: [Color(0x10FFFFFF), Color(0x06FFFFFF)]),
              ),
              child: TextField(
                controller: _secretCtrl,
                obscureText: _obscure,
                onChanged: (v) => setState(
                    () => _strength = CryptoEngine.analyzePasswordStrength(v)),
                style: const TextStyle(color: kText, fontSize: 15),
                decoration: InputDecoration(
                  labelText: _category == VaultItemCategory.secureNote
                      ? 'Secure Note *'
                      : 'Password / Secret *',
                  labelStyle: const TextStyle(
                      color: kTextDim, fontSize: 12, letterSpacing: 1),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: kNeon, size: 20),
                  suffix: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: kTextDim,
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      if (_category == VaultItemCategory.login)
                        IconButton(
                          icon: const Icon(Icons.auto_fix_high_rounded,
                              color: kNeon, size: 20),
                          onPressed: _generatePassword,
                          tooltip: 'Generate password',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_category == VaultItemCategory.login && _secretCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(CryptoEngine.strengthLabel(_strength),
                      style: TextStyle(
                          color: CryptoEngine.strengthColor(_strength),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2)),
                  Text('$_strength / 100',
                      style: const TextStyle(color: kTextMuted, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _strength / 100,
                  backgroundColor: kSurface2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      CryptoEngine.strengthColor(_strength)),
                  minHeight: 4,
                ),
              ),
            ],
            const SizedBox(height: 10),
            CyberTextField(
                controller: _websiteCtrl,
                label: 'Website / URL',
                prefixIcon: Icons.link_rounded,
                keyboardType: TextInputType.url),
            const SizedBox(height: 10),
            CyberTextField(
                controller: _notesCtrl,
                label: 'Notes',
                prefixIcon: Icons.note_outlined,
                maxLines: 3),
            const SizedBox(height: 24),
            CyberButton(
              label: _saving
                  ? 'SAVING...'
                  : widget.entry == null
                      ? 'ADD TO VAULT'
                      : 'SAVE CHANGES',
              icon: Icons.save_rounded,
              onPressed: _saving ? null : _save,
              width: double.infinity,
            ),
            const SizedBox(height: 12),
            CyberButton(
              label: 'CANCEL',
              onPressed: () => Navigator.pop(context),
              outlined: true,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultDetailSheet extends StatefulWidget {
  final VaultEntry entry;
  final AppState appState;
  const _VaultDetailSheet({required this.entry, required this.appState});

  @override
  State<_VaultDetailSheet> createState() => _VaultDetailSheetState();
}

class _VaultDetailSheetState extends State<_VaultDetailSheet> {
  bool _revealed = false;
  String _revealedSecret = '';
  bool _copying = false;

  Future<void> _reveal() async {
    if (_revealed) {
      setState(() {
        _revealed = false;
        _revealedSecret = '';
      });
      return;
    }
    final secret = await widget.appState.revealSecret(widget.entry);
    if (mounted) {
      setState(() {
        _revealed = true;
        _revealedSecret = secret;
      });
    }
  }

  Future<void> _copy() async {
    final secret = _revealed
        ? _revealedSecret
        : await widget.appState.revealSecret(widget.entry);
    await Clipboard.setData(ClipboardData(text: secret));
    setState(() => _copying = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copying = false);
    Future.delayed(const Duration(seconds: 30), () => Clipboard.setData(const ClipboardData(text: '')));
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final grad = e.category.gradient;
    final maxHeight = MediaQuery.of(context).size.height * 0.92;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: kGlassBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(context).viewInsets.bottom + 28),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2), color: kGlassBorder)),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: grad),
              boxShadow: [
                BoxShadow(color: grad.first.withValues(alpha: 0.5), blurRadius: 20)
              ],
            ),
            child: Icon(e.category.icon, color: kText, size: 30),
          ),
          const SizedBox(height: 16),
          Text(e.title,
              style: const TextStyle(
                  color: kText, fontWeight: FontWeight.w800, fontSize: 20)),
          Text(e.category.label,
              style: TextStyle(color: grad.first, fontSize: 12, letterSpacing: 2)),
          const SizedBox(height: 24),
          if (e.username.isNotEmpty) _infoRow('Username / Email', e.username, Icons.person_rounded),
          if (e.website != null) _infoRow('Website', e.website!, Icons.link_rounded),
          _secretRow(e),
          if (e.notes != null) _infoRow('Notes', e.notes!, Icons.note_rounded),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: CyberButton(
                  label: _copying ? 'COPIED!' : 'COPY SECRET',
                  icon: _copying ? Icons.check_rounded : Icons.copy_rounded,
                  onPressed: _copy,
                  gradient: _copying ? AppColors.gradientSuccess : AppColors.gradientPrimary,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => widget.appState.toggleFavorite(e.id),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kWarning.withValues(alpha: e.isFavorite ? 0.15 : 0.05),
                    border: Border.all(
                        color: kWarning.withValues(alpha: e.isFavorite ? 0.5 : 0.2)),
                  ),
                  child: Icon(
                      e.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: kWarning,
                      size: 22),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) =>
                        _AddEditVaultSheet(appState: widget.appState, entry: e),
                  );
                },
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kNeon.withValues(alpha: 0.08),
                    border: Border.all(color: kNeon.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.edit_rounded, color: kNeon, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _confirmDelete(context),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: kError.withValues(alpha: 0.08),
                    border: Border.all(color: kError.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.delete_rounded, color: kError, size: 22),
                ),
              ),
            ],
          ),
        ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: kNeon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: kTextMuted, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(color: kText, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secretRow(VaultEntry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, color: kNeon, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Password / Secret',
                      style: const TextStyle(
                          color: kTextMuted, fontSize: 10, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(
                    _revealed ? _revealedSecret : '••••••••••••••',
                    style: TextStyle(
                        color: kText,
                        fontSize: 13,
                        fontFamily: _revealed ? null : 'monospace'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                  _revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: kNeon,
                  size: 20),
              onPressed: _reveal,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: kGlassBorder)),
        title: const Text('Delete Item', style: TextStyle(color: kText)),
        content: Text(
            'Permanently delete "${widget.entry.title}"? This cannot be undone.',
            style: const TextStyle(color: kTextDim)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL', style: TextStyle(color: kTextDim))),
          TextButton(
            onPressed: () {
              widget.appState.deleteVaultEntry(widget.entry.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: kError)),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SECURITY CENTER PAGE
// ════════════════════════════════════════════════════════════════════════════

class SecurityCenterPage extends StatelessWidget {
  final AppState appState;
  const SecurityCenterPage({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: appState,
        builder: (_, __) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ENTERPRISE GRADE',
                        style: TextStyle(
                            color: kTextMuted, fontSize: 10, letterSpacing: 3)),
                    const SizedBox(height: 4),
                    const NeonText('Security Center',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        gradient: true),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _securityStatusCard()),
            SliverToBoxAdapter(child: _authMethodsCard(context)),
            SliverToBoxAdapter(child: _userProfileCard(context)),
            SliverToBoxAdapter(child: _languageCard(context)),
            SliverToBoxAdapter(child: _threatAnalysis()),
            SliverToBoxAdapter(child: _encryptionCard()),
            SliverToBoxAdapter(child: _auditLogSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _securityStatusCard() {
    final score = appState.securityScore;
    final color = score >= 80 ? kSuccess : score >= 50 ? kWarning : kError;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GlassCard(
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.security_rounded, color: color, size: 22),
                const SizedBox(width: 10),
                Text('SECURITY STATUS',
                    style: TextStyle(
                        color: kTextMuted, fontSize: 10, letterSpacing: 2)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    score >= 80 ? 'SECURE' : score >= 50 ? 'MODERATE' : 'AT RISK',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: kSurface3,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$score / 100',
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${100 - score} points to perfect',
                    style: const TextStyle(color: kTextDim, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _authMethodsCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AUTHENTICATION',
              style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          _secItem(
            Icons.lock_rounded,
            'Master Password',
            appState.hasMasterPassword ? 'Configured' : 'Not set',
            appState.hasMasterPassword,
            AppColors.gradientPrimary,
          ),
          const SizedBox(height: 8),
          _secItem(
            Icons.fingerprint,
            'Biometric Auth',
            appState.useBiometrics ? 'Active' : appState.biometricAvailable ? 'Available' : 'Not supported',
            appState.useBiometrics,
            AppColors.gradientNeon,
          ),
          const SizedBox(height: 8),
          _secItem(
            Icons.timer_rounded,
            'Auto-lock',
            'After 5 minutes of inactivity',
            true,
            AppColors.gradientCyan,
          ),
          const SizedBox(height: 8),
          _secItem(
            Icons.shield_rounded,
            'Brute Force Protection',
            'Lockout after 5 failed attempts',
            true,
            AppColors.gradientSuccess,
          ),
        ],
      ),
    );
  }

  Widget _secItem(IconData icon, String title, String status, bool active,
      List<Color> grad) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: active ? grad.first.withValues(alpha: 0.25) : kGlassBorder2,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: active ? LinearGradient(colors: grad) : null,
              color: active ? null : kSurface3,
            ),
            child: Icon(icon, color: active ? kText : kTextMuted, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: kText, fontWeight: FontWeight.w600, fontSize: 13)),
                Text(status,
                    style: TextStyle(
                        color: active ? kSuccess : kTextMuted, fontSize: 11)),
              ],
            ),
          ),
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: active ? kSuccess : kTextMuted,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _threatAnalysis() {
    final weak = appState.weakPasswordCount;
    final dupe = appState.duplicatePasswordCount;
    final total = appState.vault.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('THREAT ANALYSIS',
              style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _threatRow('Weak Passwords', weak, total, kWarning),
                const SizedBox(height: 12),
                _threatRow('Duplicate Passwords', dupe, total, kError),
                const SizedBox(height: 12),
                _threatRow('At-Risk Items', weak + dupe, total,
                    (weak + dupe) > 0 ? kError : kSuccess),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _threatRow(String label, int count, int total, Color color) {
    final frac = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: kTextDim, fontSize: 12)),
            Text('$count / $total',
                style: TextStyle(
                    color: count > 0 ? color : kSuccess,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac.clamp(0.0, 1.0),
            backgroundColor: kSurface3,
            valueColor: AlwaysStoppedAnimation<Color>(count > 0 ? color : kSuccess),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _encryptionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENCRYPTION DETAILS',
              style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                _encRow('Algorithm', 'AES-256-GCM', Icons.lock_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Key Derivation', 'SHA-256 PBKDF (200k iterations)', Icons.key_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Salt Size', '256-bit (32 bytes)', Icons.grain_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('IV Size', '96-bit (12 bytes)', Icons.shuffle_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Storage', 'Flutter Secure Storage / Keychain', Icons.storage_rounded),
                const Divider(color: kGlassBorder2, height: 20),
                _encRow('Zero-Knowledge', 'Yes — keys never leave device', Icons.visibility_off_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _encRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: kNeon, size: 16),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: kTextDim, fontSize: 12)),
        const Spacer(),
        Flexible(
          child: Text(value,
              style: const TextStyle(color: kText, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _auditLogSection() {
    final events = appState.auditLog.take(10).toList();
    if (events.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AUDIT LOG',
              style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: events.map((e) {
                final color = e.action == 'AUTH'
                    ? kCyan
                    : e.action == 'SECURITY'
                        ? kError
                        : e.action == 'FILES'
                            ? kWarning
                            : kNeon;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [BoxShadow(color: color, blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(e.detail,
                            style: const TextStyle(color: kTextDim, fontSize: 11)),
                      ),
                      Text(
                        _fmtTime(e.timestamp),
                        style: const TextStyle(color: kTextMuted, fontSize: 10),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _userProfileCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('USER PROFILE', style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: AppColors.gradientNeon),
                        boxShadow: [BoxShadow(color: kNeon.withValues(alpha: 0.3), blurRadius: 16)],
                      ),
                      child: Center(
                        child: Text(
                          appState.fullName.isNotEmpty ? appState.fullName[0].toUpperCase() : '?',
                          style: const TextStyle(color: kText, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appState.fullName.isNotEmpty ? appState.fullName : 'Unknown', style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(appState.country.isNotEmpty ? appState.country : 'Not set', style: const TextStyle(color: kTextDim, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: kSuccess.withValues(alpha: 0.1),
                        border: Border.all(color: kSuccess.withValues(alpha: 0.3)),
                      ),
                      child: const Text('SAVED', style: TextStyle(color: kSuccess, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LANGUAGE', style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3)),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SELECT LANGUAGE', style: TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kSupportedLanguages.map((lang) {
                    final selected = appState.preferredLanguage == lang['code'];
                    return GestureDetector(
                      onTap: () => appState.updateLanguage(lang['code']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: selected
                              ? const LinearGradient(colors: AppColors.gradientNeon)
                              : null,
                          color: selected ? null : kSurface3,
                          border: Border.all(color: selected ? kNeon : kGlassBorder2, width: selected ? 1.5 : 1),
                          boxShadow: selected ? [BoxShadow(color: kNeon.withValues(alpha: 0.3), blurRadius: 10)] : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lang['flag']!, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(lang['native']!, style: TextStyle(color: selected ? kText : kTextDim, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ════════════════════════════════════════════════════════════════════════════
// USER REGISTRATION SCREEN
// ════════════════════════════════════════════════════════════════════════════

class UserRegistrationScreen extends StatefulWidget {
  final AppState appState;
  const UserRegistrationScreen({super.key, required this.appState});

  @override
  State<UserRegistrationScreen> createState() => _UserRegistrationScreenState();
}

class _UserRegistrationScreenState extends State<UserRegistrationScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  final _nameCtrl = TextEditingController();
  String _selectedCountry = '';
  String _selectedLanguage = 'en';

  late AnimationController _entryCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _stepCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _floatAnim;
  late Animation<double> _stepFade;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _stepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.7, curve: Curves.easeOut));
    _slideUp = Tween<double>(begin: 60, end: 0).animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _stepFade = CurvedAnimation(parent: _stepCtrl, curve: Curves.easeOut);
    _stepCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _floatCtrl.dispose();
    _stepCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) return;
    if (_step == 1 && _selectedCountry.isEmpty) return;
    if (_step < 2) {
      _stepCtrl.reverse().then((_) {
        setState(() => _step++);
        _stepCtrl.forward();
      });
    } else {
      _complete();
    }
  }

  void _prevStep() {
    if (_step > 0) {
      _stepCtrl.reverse().then((_) {
        setState(() => _step--);
        _stepCtrl.forward();
      });
    }
  }

  Future<void> _complete() async {
    await widget.appState.saveUserProfile(
      _nameCtrl.text.trim(),
      _selectedCountry,
      _selectedLanguage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: GridPainter(1.0))),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.4),
                  radius: 1.2,
                  colors: [Color(0xFF1A0030), Color(0xFF050505)],
                ),
              ),
            ),
          ),
          ParticleSystem(child: const SizedBox.expand(), count: 40),
          SafeArea(
            child: AnimatedBuilder(
              animation: Listenable.merge([_fadeIn, _slideUp]),
              builder: (_, __) => FadeTransition(
                opacity: _fadeIn,
                child: Transform.translate(
                  offset: Offset(0, _slideUp.value),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      AnimatedBuilder(
                        animation: _floatAnim,
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _floatAnim.value),
                          child: _buildLogo(),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildStepIndicator(),
                      const SizedBox(height: 28),
                      Expanded(
                        child: FadeTransition(
                          opacity: _stepFade,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                      _buildActions(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: AppColors.gradientPrimary, begin: Alignment.topLeft, end: Alignment.bottomRight),
            boxShadow: [
              BoxShadow(color: kPrimary.withValues(alpha: 0.6), blurRadius: 32, spreadRadius: 4),
              BoxShadow(color: kNeon.withValues(alpha: 0.2), blurRadius: 64, spreadRadius: 8),
            ],
          ),
          child: const Icon(Icons.shield_rounded, color: kText, size: 38),
        ),
        const SizedBox(height: 12),
        const NeonText('CIPHERGUARD', fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6, gradient: true),
        const SizedBox(height: 4),
        Text('WELCOME — LET\'S GET YOU SET UP', style: TextStyle(color: kTextMuted, fontSize: 9, letterSpacing: 3)),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final labels = ['Profile', 'Country', 'Language'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < _step;
          final active = i == _step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 2,
                    color: i == 0 ? Colors.transparent : (done || active ? kNeon.withValues(alpha: 0.5) : kGlassBorder2),
                  ),
                ),
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: active || done
                            ? const LinearGradient(colors: AppColors.gradientNeon)
                            : null,
                        color: active || done ? null : kSurface3,
                        border: Border.all(
                          color: active ? kNeon : done ? kNeon.withValues(alpha: 0.5) : kGlassBorder2,
                          width: active ? 2 : 1,
                        ),
                        boxShadow: active ? [BoxShadow(color: kNeon.withValues(alpha: 0.5), blurRadius: 12)] : [],
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded, color: kText, size: 16)
                            : Text('${i + 1}', style: TextStyle(color: active ? kText : kTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], style: TextStyle(color: active ? kNeon : kTextMuted, fontSize: 9, letterSpacing: 1)),
                  ],
                ),
                Expanded(
                  child: Container(
                    height: 2,
                    color: i == 2 ? Colors.transparent : (i < _step ? kNeon.withValues(alpha: 0.5) : kGlassBorder2),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildNameStep();
      case 1:
        return _buildCountryStep();
      case 2:
        return _buildLanguageStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NeonText('YOUR NAME', fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, gradient: true),
        const SizedBox(height: 6),
        Text('How should we address you?', style: TextStyle(color: kTextDim, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 32),
        GlassCard(
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Enter your full name',
              hintStyle: TextStyle(color: kTextMuted, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: kNeon, size: 22),
            ),
            onSubmitted: (_) => _nextStep(),
            autofocus: true,
          ),
        ),
        const SizedBox(height: 20),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: kCyan, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your name is stored securely on-device and used to personalize your experience.',
                  style: TextStyle(color: kTextDim, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountryStep() {
    final filtered = kCountries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NeonText('YOUR COUNTRY', fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, gradient: true),
        const SizedBox(height: 6),
        Text('Select your country of residence', style: TextStyle(color: kTextDim, fontSize: 13)),
        const SizedBox(height: 24),
        ...filtered.map((c) {
          final selected = _selectedCountry == c;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCountry = c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: selected
                      ? LinearGradient(colors: AppColors.gradientPrimary.map((c) => c.withValues(alpha: 0.2)).toList())
                      : const LinearGradient(colors: [Color(0x0AFFFFFF), Color(0x06FFFFFF)]),
                  border: Border.all(color: selected ? kNeon : kGlassBorder2, width: selected ? 1.5 : 1),
                  boxShadow: selected ? [BoxShadow(color: kNeon.withValues(alpha: 0.2), blurRadius: 12)] : [],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, color: kNeon, size: 16),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c, style: TextStyle(color: selected ? kText : kTextDim, fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
                    if (selected) const Icon(Icons.check_circle_rounded, color: kNeon, size: 18),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLanguageStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const NeonText('YOUR LANGUAGE', fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4, gradient: true),
        const SizedBox(height: 6),
        Text('Choose your preferred language', style: TextStyle(color: kTextDim, fontSize: 13)),
        const SizedBox(height: 24),
        ...kSupportedLanguages.map((lang) {
          final selected = _selectedLanguage == lang['code'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedLanguage = lang['code']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: selected
                      ? LinearGradient(colors: AppColors.gradientPrimary.map((c) => c.withValues(alpha: 0.25)).toList(), begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : const LinearGradient(colors: [Color(0x0CFFFFFF), Color(0x06FFFFFF)]),
                  border: Border.all(color: selected ? kNeon : kGlassBorder2, width: selected ? 2 : 1),
                  boxShadow: selected ? [BoxShadow(color: kNeon.withValues(alpha: 0.3), blurRadius: 20)] : [],
                ),
                child: Row(
                  children: [
                    Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lang['native']!, style: TextStyle(color: selected ? kText : kTextDim, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(lang['name']!, style: TextStyle(color: kTextMuted, fontSize: 11)),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? kNeon : Colors.transparent,
                        border: Border.all(color: selected ? kNeon : kGlassBorder, width: 2),
                        boxShadow: selected ? [BoxShadow(color: kNeon.withValues(alpha: 0.4), blurRadius: 10)] : [],
                      ),
                      child: selected ? const Icon(Icons.check_rounded, color: kBg, size: 14) : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActions() {
    final canNext = (_step == 0 && _nameCtrl.text.trim().isNotEmpty) ||
        (_step == 1 && _selectedCountry.isNotEmpty) ||
        _step == 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CyberButton(
                  label: 'BACK',
                  onPressed: _prevStep,
                  outlined: true,
                  height: 52,
                ),
              ),
            ),
          Expanded(
            flex: _step > 0 ? 2 : 1,
            child: CyberButton(
              label: _step == 2 ? 'GET STARTED' : 'NEXT',
              icon: _step == 2 ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
              onPressed: canNext ? _nextStep : null,
              gradient: AppColors.gradientNeon,
              height: 52,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// INFO / DEVELOPER PORTFOLIO PAGE
// ════════════════════════════════════════════════════════════════════════════

class InfoPage extends StatefulWidget {
  final AppState appState;
  const InfoPage({super.key, required this.appState});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _floatCtrl;
  late AnimationController _rotateCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimmerCtrl;
  late Animation<double> _heroFade;
  late Animation<double> _heroSlide;
  late Animation<double> _floatAnim;
  late Animation<double> _rotateAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _heroSlide = Tween<double>(begin: 80, end: 0).animate(CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.1, 0.9, curve: Curves.easeOutCubic)));
    _floatAnim = Tween<double>(begin: -8, end: 8).animate(CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _shimmerAnim = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _floatCtrl.dispose();
    _rotateCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeroSection()),
          SliverToBoxAdapter(child: _buildAboutCard()),
          SliverToBoxAdapter(child: _buildSkillsSection()),
          SliverToBoxAdapter(child: _buildContactSection()),
          SliverToBoxAdapter(child: _buildProjectsSection()),
          SliverToBoxAdapter(child: _buildTechStack()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Stack(
      children: [
        SizedBox(
          height: 420,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 1.4,
                      colors: [Color(0xFF1A0840), Color(0xFF0A0518), Color(0xFF050505)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: GridPainter(0.6))),
              AnimatedBuilder(
                animation: _rotateAnim,
                builder: (_, __) => Positioned(
                  top: 40,
                  left: -60,
                  child: Transform.rotate(
                    angle: _rotateAnim.value * 2 * pi,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kNeon.withValues(alpha: 0.06), width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _rotateAnim,
                builder: (_, __) => Positioned(
                  top: 80,
                  right: -80,
                  child: Transform.rotate(
                    angle: -_rotateAnim.value * 2 * pi * 0.7,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimary.withValues(alpha: 0.08), width: 1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_heroFade, _heroSlide]),
                  builder: (_, __) => FadeTransition(
                    opacity: _heroFade,
                    child: Transform.translate(
                      offset: Offset(0, _heroSlide.value),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              const SizedBox(height: 16),
                              _buildAvatarSection(),
                              const SizedBox(height: 20),
                              _buildHeroText(),
                              const SizedBox(height: 16),
                              _buildHeroTags(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnim, _pulseAnim, _rotateAnim]),
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _floatAnim.value * 0.5),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: _rotateAnim.value * 2 * pi,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kNeon.withValues(alpha: 0.2 * _pulseAnim.value), width: 1),
                ),
              ),
            ),
            Transform.rotate(
              angle: -_rotateAnim.value * 2 * pi * 0.6,
              child: Container(
                width: 118,
                height: 118,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kPrimary.withValues(alpha: 0.35 * _pulseAnim.value), width: 1.5),
                ),
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A0860), Color(0xFF8A2BE2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: kNeon.withValues(alpha: 0.7 * _pulseAnim.value), width: 2.5),
                boxShadow: [
                  BoxShadow(color: kPrimary.withValues(alpha: 0.6 * _pulseAnim.value), blurRadius: 40, spreadRadius: 6),
                  BoxShadow(color: kNeon.withValues(alpha: 0.25 * _pulseAnim.value), blurRadius: 70, spreadRadius: 12),
                ],
              ),
              child: const Icon(Icons.code_rounded, color: kNeon, size: 48),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroText() {
    return Column(
      children: [
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [kNeon, kCyan, kNeon],
            stops: [0, 0.5, 1],
          ).createShader(b),
          child: const Text(
            'ILIA NOTHING',
            style: TextStyle(color: kText, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: AppColors.gradientPrimary.map((c) => c.withValues(alpha: 0.25)).toList()),
            border: Border.all(color: kNeon.withValues(alpha: 0.3)),
          ),
          child: const Text('Full-Stack Developer & Security Researcher',
              style: TextStyle(color: kNeon, fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildHeroTags() {
    final tags = ['Flutter', 'Dart', 'Security', 'Open Source', 'CipherGuard'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: tags.map((t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: kGlass2,
          border: Border.all(color: kGlassBorder2),
        ),
        child: Text(t, style: const TextStyle(color: kTextDim, fontSize: 10, letterSpacing: 0.5)),
      )).toList(),
    );
  }

  Widget _buildAboutCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: GlassCard(
        gradientColors: [const Color(0x14CC66FF), const Color(0x08050505)],
        borderColor: kGlassBorder,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(colors: AppColors.gradientNeon),
                  ),
                  child: const Icon(Icons.person_rounded, color: kText, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('ABOUT', style: TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 3)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ilia Nothing is a passionate software developer and security researcher specializing in mobile application development, cryptography, and privacy-focused tools. Creator of CipherGuard — a zero-knowledge AES-256 encrypted vault for Android and iOS.',
              style: const TextStyle(color: kTextDim, fontSize: 13, height: 1.7),
            ),
            const SizedBox(height: 12),
            Text(
              'Focused on building tools that respect user privacy and security, leveraging cutting-edge cryptographic standards to deliver enterprise-grade protection in consumer applications.',
              style: const TextStyle(color: kTextDim, fontSize: 13, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    final skills = [
      ('Flutter / Dart', 0.95, AppColors.gradientCyan),
      ('Cryptography & Security', 0.90, AppColors.gradientNeon),
      ('Mobile Development', 0.92, AppColors.gradientPrimary),
      ('Backend Development', 0.80, AppColors.gradientSecondary),
      ('UI/UX Design', 0.85, AppColors.gradientSuccess),
      ('Open Source', 0.88, AppColors.gradientGold),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('SKILLS', Icons.psychology_rounded),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: skills.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _skillBar(s.$1, s.$2, s.$3),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _skillBar(String label, double value, List<Color> grad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: kTextDim, fontSize: 12, fontWeight: FontWeight.w500)),
            Text('${(value * 100).toInt()}%', style: TextStyle(color: grad.first, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 6, color: kSurface3),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: grad),
                    boxShadow: [BoxShadow(color: grad.first.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('CONTACT', Icons.contact_page_rounded),
          const SizedBox(height: 12),
          _contactCard(Icons.code_rounded, 'GitHub', 'V0IDNETWORK', 'https://github.com/V0IDNETWORK', AppColors.gradientDark),
          const SizedBox(height: 10),
          _contactCard(Icons.language_rounded, 'Website', 'voidnetwork.ir', 'https://voidnetwork.ir', AppColors.gradientCyan),
          const SizedBox(height: 10),
          _contactCard(Icons.send_rounded, 'Telegram', '@ilianothing', 'https://t.me/ilianothing', AppColors.gradientPrimary),
          const SizedBox(height: 10),
          _contactCard(Icons.email_rounded, 'Email', 'contact@voidnetwork', 'mailto:ilianothingg@gmail.com', AppColors.gradientSuccess),
        ],
      ),
    );
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    final isWebLink = uri.scheme == 'http' || uri.scheme == 'https';
    try {
      final launched = await launchUrl(
        uri,
        mode: isWebLink
            ? LaunchMode.externalApplication
            : LaunchMode.externalNonBrowserApplication,
      );
      if (!launched && mounted) {
        _showLinkError(url);
      }
    } catch (_) {
      if (mounted) {
        _showLinkError(url);
      }
    }
  }

  void _showLinkError(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open $url'),
        backgroundColor: kError,
      ),
    );
  }

  Widget _contactCard(IconData icon, String platform, String handle, String url, List<Color> grad) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      onTap: () => _openLink(url),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: grad.first.withValues(alpha: 0.4), blurRadius: 16)],
            ),
            child: Icon(icon, color: kText, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(platform, style: const TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w700)),
                Text(handle,
                    style: const TextStyle(color: kText, fontSize: 14, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.open_in_new_rounded, color: kNeon.withValues(alpha: 0.5), size: 16),
        ],
      ),
    );
  }

  Widget _buildProjectsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('PROJECTS', Icons.rocket_launch_rounded),
          const SizedBox(height: 12),
          GlassCard(
            gradientColors: [const Color(0x108A2BE2), kSurface2.withValues(alpha: 0.4)],
            borderColor: kPrimary.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(colors: AppColors.gradientNeon),
                        boxShadow: [BoxShadow(color: kNeon.withValues(alpha: 0.4), blurRadius: 16)],
                      ),
                      child: const Icon(Icons.shield_rounded, color: kText, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CipherGuard', style: TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.w800)),
                          Text('AES-256-GCM Password Manager', style: TextStyle(color: kNeon, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: kSuccess.withValues(alpha: 0.12),
                        border: Border.all(color: kSuccess.withValues(alpha: 0.3)),
                      ),
                      child: const Text('ACTIVE', style: TextStyle(color: kSuccess, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'A premium zero-knowledge encrypted password manager featuring AES-256-GCM vault, biometric authentication, secure file storage, and a comprehensive security center.',
                  style: TextStyle(color: kTextDim, fontSize: 12, height: 1.6),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: ['Flutter', 'Dart', 'AES-256', 'Biometrics', 'Zero-Knowledge'].map((t) =>
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: kNeon.withValues(alpha: 0.08),
                        border: Border.all(color: kNeon.withValues(alpha: 0.2)),
                      ),
                      child: Text(t, style: const TextStyle(color: kNeon, fontSize: 10)),
                    ),
                  ).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechStack() {
    final techs = [
      (Icons.phone_android_rounded, 'Flutter', kCyan),
      (Icons.lock_rounded, 'AES-256', kNeon),
      (Icons.fingerprint, 'Biometrics', kPrimary),
      (Icons.storage_rounded, 'Secure Storage', kSecondary),
      (Icons.code_rounded, 'Dart', kAccent),
      (Icons.security_rounded, 'PBKDF2', kSuccess),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('TECH STACK', Icons.developer_mode_rounded),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: techs.map((t) => GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(t.$1, color: t.$3, size: 22),
                  const SizedBox(height: 6),
                  Text(t.$2, style: TextStyle(color: t.$3, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5), textAlign: TextAlign.center),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(colors: AppColors.gradientNeon),
          ),
          child: Icon(icon, color: kText, size: 14),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: kTextMuted, fontSize: 10, letterSpacing: 3, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: kGlassBorder2)),
      ],
    );
  }
}
