import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _usernameKey = 'session_username';
  static const _roleKey = 'session_role';

  static Future<void> saveSession({required String username, required String role}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_usernameKey, username);
    await p.setString(_roleKey, role);
  }

  static Future<Map<String, String>> getSession() async {
    final p = await SharedPreferences.getInstance();
    return {
      'username': p.getString(_usernameKey) ?? '',
      'role': p.getString(_roleKey) ?? 'Admin',
    };
  }

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_usernameKey);
    await p.remove(_roleKey);
  }
}
