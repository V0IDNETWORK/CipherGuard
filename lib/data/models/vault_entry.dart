import 'package:flutter/material.dart';
import '../../core/config/constants.dart';

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
      case VaultItemCategory.login:
        return 'Login';
      case VaultItemCategory.secureNote:
        return 'Secure Note';
      case VaultItemCategory.creditCard:
        return 'Credit Card';
      case VaultItemCategory.identity:
        return 'Identity';
      case VaultItemCategory.sshKey:
        return 'SSH Key';
      case VaultItemCategory.apiKey:
        return 'API Key';
      case VaultItemCategory.license:
        return 'License';
      case VaultItemCategory.secret:
        return 'Secret';
      case VaultItemCategory.bankAccount:
        return 'Bank Account';
    }
  }

  IconData get icon {
    switch (this) {
      case VaultItemCategory.login:
        return Icons.lock_rounded;
      case VaultItemCategory.secureNote:
        return Icons.note_rounded;
      case VaultItemCategory.creditCard:
        return Icons.credit_card_rounded;
      case VaultItemCategory.identity:
        return Icons.badge_rounded;
      case VaultItemCategory.sshKey:
        return Icons.terminal_rounded;
      case VaultItemCategory.apiKey:
        return Icons.api_rounded;
      case VaultItemCategory.license:
        return Icons.verified_rounded;
      case VaultItemCategory.secret:
        return Icons.security_rounded;
      case VaultItemCategory.bankAccount:
        return Icons.account_balance_rounded;
    }
  }

  List<Color> get gradient {
    switch (this) {
      case VaultItemCategory.login:
        return AppColors.gradientPrimary;
      case VaultItemCategory.secureNote:
        return AppColors.gradientCyan;
      case VaultItemCategory.creditCard:
        return AppColors.gradientGold;
      case VaultItemCategory.identity:
        return AppColors.gradientSuccess;
      case VaultItemCategory.sshKey:
        return [const Color(0xFF00FF88), const Color(0xFF00D4FF)];
      case VaultItemCategory.apiKey:
        return AppColors.gradientNeon;
      case VaultItemCategory.license:
        return AppColors.gradientGold;
      case VaultItemCategory.secret:
        return AppColors.gradientFire;
      case VaultItemCategory.bankAccount:
        return AppColors.gradientSuccess;
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
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : null,
        isFavorite: j['isFavorite'] as bool? ?? false,
        strengthScore: j['strengthScore'] as int? ?? 0,
      );
}

class AuditEvent {
  final String id;
  final String action;
  final String detail;
  final DateTime timestamp;

  AuditEvent({
    required this.id,
    required this.action,
    required this.detail,
    required this.timestamp,
  });

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
