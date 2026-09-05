import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _usernameKey = 'session_username';
  static const _roleKey = 'session_role';
  static const _employeeIdKey = 'session_employee_id';
  static const _employeeCredsKey = 'employee_credentials';
  static const _adminUsernameKey = 'admin_profile_username';
  static const _adminPasswordKey = 'admin_profile_password';

  static Future<void> saveSession({required String username, required String role, int? employeeId}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_usernameKey, username);
    await p.setString(_roleKey, role);
    if (employeeId != null) { await p.setInt(_employeeIdKey, employeeId); } else { await p.remove(_employeeIdKey); }
  }

  static Future<Map<String, String>> getSession() async {
    final p = await SharedPreferences.getInstance();
    return {
      'username': p.getString(_usernameKey) ?? '',
      'role': p.getString(_roleKey) ?? 'Admin',
      'employeeId': '${p.getInt(_employeeIdKey) ?? ''}',
    };
  }

  static Future<void> saveEmployeeCredential({required int employeeId, required String username, required String password}) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_employeeCredsKey) ?? <String>[];
    raw.removeWhere((x) => x.startsWith('$employeeId|'));
    raw.add('$employeeId|${Uri.encodeComponent(username)}|${Uri.encodeComponent(password)}');
    await p.setStringList(_employeeCredsKey, raw);
  }

  static Future<Map<String, dynamic>?> findEmployeeCredential(String username, String password) async {
    final p = await SharedPreferences.getInstance();
    for (final item in p.getStringList(_employeeCredsKey) ?? const <String>[]) {
      final parts = item.split('|');
      if (parts.length == 3 && Uri.decodeComponent(parts[1]) == username && Uri.decodeComponent(parts[2]) == password) {
        return {'employeeId': int.tryParse(parts[0]) ?? 0, 'username': username};
      }
    }
    return null;
  }

  static Future<void> saveAdminCredentials({required String username, required String password}) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_adminUsernameKey, username);
    await p.setString(_adminPasswordKey, password);
  }

  static Future<Map<String, String>> getAdminCredentials() async {
    final p = await SharedPreferences.getInstance();
    return {'username': p.getString(_adminUsernameKey) ?? 'admin', 'password': p.getString(_adminPasswordKey) ?? '1234'};
  }

  static Future<void> clearSession() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_usernameKey);
    await p.remove(_roleKey);
    await p.remove(_employeeIdKey);
  }
}
