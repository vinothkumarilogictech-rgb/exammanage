import 'package:flutter/foundation.dart';
import '../services/dio_client.dart';
import '../services/session_service.dart';

class AuthProvider extends ChangeNotifier {
  final DioClient api = DioClient();

  bool loading = false;
  bool authenticated = false;
  String username = '';
  String role = 'Admin';
  String? error;

  Future<void> checkSession() async {
    final token = await api.readAccessToken();
    authenticated = token != null && token.isNotEmpty;
    if (authenticated) {
      final session = await SessionService.getSession();
      username = session['username'] ?? '';
      role = session['role'] ?? 'Admin';
    }
    notifyListeners();
  }

  Future<bool> login(String user, String pass) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final r = await api.login(user.trim(), pass);
      if (r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300 &&
          r.data is Map && r.data['success'] == true) {
        final data = Map<String, dynamic>.from(r.data['data'] ?? {});
        await api.saveTokens(Map<String, dynamic>.from(data['tokens'] ?? {}));
        authenticated = true;
        username = user.trim();
        role = '${data['user']?['role'] ?? 'Admin'}';
        await SessionService.saveSession(username: username, role: role);
        return true;
      }
      error = '${r.data?['message'] ?? 'Login failed'}';
      return false;
    } catch (e) {
      error = 'Unable to connect to the Exam Management API.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.clearTokens();
    await SessionService.clearSession();
    authenticated = false;
    username = '';
    role = 'Admin';
    notifyListeners();
  }
}
