import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SavedAccount {
  final String userId;
  final String name;
  final String? username;
  final String? avatarUrl;
  final String? role;
  final String? sessionJson; // Store the session string to re-authenticate

  SavedAccount({
    required this.userId,
    required this.name,
    this.username,
    this.avatarUrl,
    this.role,
    this.sessionJson,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'name': name,
    'username': username,
    'avatarUrl': avatarUrl,
    'role': role,
    'sessionJson': sessionJson,
  };

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    userId: json['userId'],
    name: json['name'],
    username: json['username'],
    avatarUrl: json['avatarUrl'],
    role: json['role'],
    sessionJson: json['sessionJson'],
  );
}

class AccountService {
  static const String _keyAccounts = 'saved_accounts';
  static const String _keyCurrentAccountId = 'current_account_id';

  static Future<void> saveAccount({
    required String userId,
    required String name,
    String? username,
    String? avatarUrl,
    String? role,
    String? sessionJson,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    
    final newAccount = SavedAccount(
      userId: userId,
      name: name,
      username: username,
      avatarUrl: avatarUrl,
      role: role,
      sessionJson: sessionJson,
    );

    // Remove old entry if exists
    accounts.removeWhere((a) => a.userId == userId);
    accounts.add(newAccount);

    final encoded = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_keyAccounts, encoded);
    await prefs.setString(_keyCurrentAccountId, userId);
  }

  static Future<List<SavedAccount>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyAccounts) ?? [];
    return list.map((item) => SavedAccount.fromJson(jsonDecode(item))).toList();
  }

  static Future<void> removeAccount(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await getSavedAccounts();
    accounts.removeWhere((a) => a.userId == userId);
    
    final encoded = accounts.map((a) => jsonEncode(a.toJson())).toList();
    await prefs.setStringList(_keyAccounts, encoded);
    
    final currentId = prefs.getString(_keyCurrentAccountId);
    if (currentId == userId) {
      await prefs.remove(_keyCurrentAccountId);
    }
  }

  static Future<void> switchAccount(String userId) async {
    final accounts = await getSavedAccounts();
    final account = accounts.firstWhere((a) => a.userId == userId);
    
    if (account.sessionJson != null) {
      // Restore session in Supabase
      await Supabase.instance.client.auth.recoverSession(account.sessionJson!);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrentAccountId, userId);
    }
  }
}
