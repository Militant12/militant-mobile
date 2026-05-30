import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class SavedAccount {
  final String id;
  final String username;
  final String baseUrl;
  final String token;
  final int? userId;
  final String? avatarUrl;
  final DateTime updatedAt;

  const SavedAccount({
    required this.id,
    required this.username,
    required this.baseUrl,
    required this.token,
    required this.updatedAt,
    this.userId,
    this.avatarUrl,
  });

  String get displayName => username.trim().isEmpty ? 'Compte' : username;

  String get initial {
    final name = displayName.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'base_url': baseUrl,
    'token': token,
    'user_id': userId,
    'avatar_url': avatarUrl,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) {
    final baseUrl = ApiService.normalizeBaseUrl(
      (json['base_url'] ?? '').toString(),
    );
    final username = (json['username'] ?? '').toString();
    final userId = int.tryParse((json['user_id'] ?? '').toString());
    final id = (json['id'] ?? _buildId(baseUrl, userId, username)).toString();

    return SavedAccount(
      id: id,
      username: username,
      baseUrl: baseUrl,
      token: (json['token'] ?? '').toString(),
      userId: userId,
      avatarUrl: json['avatar_url']?.toString(),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String buildId(String baseUrl, int? userId, String username) {
    return _buildId(ApiService.normalizeBaseUrl(baseUrl), userId, username);
  }

  static String _buildId(String baseUrl, int? userId, String username) {
    final accountKey = userId?.toString() ?? username.trim().toLowerCase();
    return '$baseUrl::$accountKey';
  }
}

class AccountSwitcherService {
  static const _accountsKey = 'saved_accounts_v1';

  static Future<List<SavedAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_accountsKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final accounts = decoded
          .whereType<Map>()
          .map((item) => SavedAccount.fromJson(Map<String, dynamic>.from(item)))
          .where((account) => account.token.trim().isNotEmpty)
          .toList();

      accounts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return accounts;
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAccount({
    required String baseUrl,
    required String token,
    required String username,
    int? userId,
    String? avatarUrl,
  }) async {
    final normalizedBaseUrl = ApiService.normalizeBaseUrl(baseUrl);
    final id = SavedAccount.buildId(normalizedBaseUrl, userId, username);
    final nextAccount = SavedAccount(
      id: id,
      username: username,
      baseUrl: normalizedBaseUrl,
      token: token,
      userId: userId,
      avatarUrl: avatarUrl,
      updatedAt: DateTime.now(),
    );

    await upsertAccount(nextAccount);
  }

  static Future<void> upsertAccount(SavedAccount account) async {
    final accounts = await loadAccounts();
    final updated = [
      account,
      ...accounts.where((saved) => saved.id != account.id),
    ];

    await _saveAccounts(updated.take(8).toList());
  }

  static Future<void> removeAccount(String accountId) async {
    final accounts = await loadAccounts();
    await _saveAccounts(
      accounts.where((account) => account.id != accountId).toList(),
    );
  }

  static Future<void> activateAccount(SavedAccount account) async {
    await ApiService.setActiveSession(
      baseUrl: account.baseUrl,
      token: account.token,
      userId: account.userId,
    );
  }

  static Future<SavedAccount?> activeSessionSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('base_url');
    final token = prefs.getString('api_token');
    if (baseUrl == null || token == null || token.trim().isEmpty) {
      return null;
    }

    final userId = prefs.getInt('user_id');
    final normalizedBaseUrl = ApiService.normalizeBaseUrl(baseUrl);
    final accounts = await loadAccounts();
    final id = SavedAccount.buildId(normalizedBaseUrl, userId, '');
    for (final account in accounts) {
      final sameUser = userId != null && account.userId == userId;
      final sameSession =
          account.baseUrl == normalizedBaseUrl &&
          (sameUser || account.token == token);
      if (account.id == id || sameSession) return account;
    }

    return SavedAccount(
      id: id,
      username: '',
      baseUrl: normalizedBaseUrl,
      token: token,
      userId: userId,
      updatedAt: DateTime.now(),
    );
  }

  static Future<String?> currentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString('base_url');
    final token = prefs.getString('api_token');
    if (baseUrl == null || token == null || token.isEmpty) return null;

    final userId = prefs.getInt('user_id');
    final normalizedBaseUrl = ApiService.normalizeBaseUrl(baseUrl);
    final accounts = await loadAccounts();
    final id = SavedAccount.buildId(normalizedBaseUrl, userId, '');
    for (final account in accounts) {
      final sameUser = userId != null && account.userId == userId;
      final sameSession =
          account.baseUrl == normalizedBaseUrl &&
          (sameUser || account.token == token);
      if (account.id == id || sameSession) return account.id;
    }

    return id;
  }

  static Future<void> _saveAccounts(List<SavedAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((account) => account.toJson()).toList()),
    );
  }
}
