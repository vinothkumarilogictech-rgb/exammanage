import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../services/dio_client.dart';
import '../services/session_service.dart';

class AuthProvider extends ChangeNotifier {
  final DioClient api = DioClient();

  bool loading = false;
  bool authenticated = false;
  String username = '';
  String role = 'Admin';
  String? error;
  int? employeeId;

  // Preserves which tab (Admin/User) was last signed in, so that after
  // logout the login screen reopens on the same tab instead of always
  // defaulting to Admin.
  String lastRole = 'Admin';

  Future<void> checkSession() async {
    final token = await api.readAccessToken();
    final session = await SessionService.getSession();

    if (token == null || token.isEmpty) {
      authenticated = false;
      username = '';
      role = 'Admin';
      employeeId = null;
      notifyListeners();
      return;
    }

    try {
      final response = await api.me();
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data['data'] ?? {})
            : <String, dynamic>{};

        authenticated = true;
        username = '${data['username'] ?? session['username'] ?? ''}';
        role = '${data['role'] ?? session['role'] ?? 'Admin'}';
        lastRole = role;

        final rawEmployeeId = data['employee_id'] ?? session['employeeId'];
        employeeId = rawEmployeeId is int
            ? rawEmployeeId
            : int.tryParse('$rawEmployeeId');

        await SessionService.saveSession(
          username: username,
          role: role,
          employeeId: employeeId,
        );
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('Session verification failed: $e');
    }

    await api.clearTokens();
    await SessionService.clearSession();
    authenticated = false;
    username = '';
    role = 'Admin';
    employeeId = null;
    notifyListeners();
  }

  Future<bool> login(
    String user,
    String pass, {
    required bool adminMode,
  }) async {
    final cleanUser = user.trim();
    loading = true;
    error = null;
    notifyListeners();

    try {
      if (cleanUser.isEmpty || pass.isEmpty) {
        error = 'Please enter username and password.';
        return false;
      }

      try {
        // Both Admin and Employee are authenticated by the backend.
        // The backend returns the role and, for employees, employee_id.
        final response = await api.login(cleanUser, pass);

        if (response.statusCode == null ||
            response.statusCode! < 200 ||
            response.statusCode! >= 300 ||
            response.data is! Map) {
          error = 'Invalid username or password.';
          return false;
        }

        final responseData = Map<String, dynamic>.from(response.data);

        if (responseData['success'] != true) {
          error = 'Invalid username or password.';
          return false;
        }

        final data = Map<String, dynamic>.from(responseData['data'] ?? {});

        final rawTokens = data['tokens'];
        if (rawTokens is! Map) {
          error = 'Login succeeded but no access token was received.';
          return false;
        }

        final tokens = Map<String, dynamic>.from(rawTokens);
        final accessToken = tokens['access']?.toString();

        if (accessToken == null ||
            accessToken.isEmpty ||
            accessToken == 'null') {
          error = 'Login succeeded but no access token was received.';
          return false;
        }

        final userData = data['user'] is Map
            ? Map<String, dynamic>.from(data['user'])
            : <String, dynamic>{};

        final loggedRole = '${userData['role'] ?? data['role'] ?? 'Admin'}';

        // Admin tab must authenticate an Admin.
        if (adminMode && loggedRole != 'Admin') {
          await api.clearTokens();
          error = 'This account is an Employee. Select User login.';
          return false;
        }

        // User tab must authenticate an Employee.
        if (!adminMode && loggedRole != 'Employee') {
          await api.clearTokens();
          error = 'This account is an Admin. Select Admin login.';
          return false;
        }

        await api.saveTokens(tokens);

        authenticated = true;
        username = '${userData['username'] ?? cleanUser}';
        role = loggedRole;
        lastRole = loggedRole;

        final rawEmployeeId = userData['employee_id'] ?? data['employee_id'];
        employeeId = rawEmployeeId is int
            ? rawEmployeeId
            : int.tryParse('$rawEmployeeId');

        if (role != 'Employee') {
          employeeId = null;
        }

        await SessionService.saveSession(
          username: username,
          role: role,
          employeeId: employeeId,
        );

        return true;
      } on DioException catch (e) {
        debugPrint('Login status: ${e.response?.statusCode}');
        debugPrint('Login response: ${e.response?.data}');

        if (e.response?.statusCode == 401) {
          error = 'Invalid username or password.';
        } else {
          error = 'Unable to connect to server.';
        }
        return false;
      } catch (e) {
        debugPrint('Login error: $e');
        error = 'Unable to connect to server.';
        return false;
      }
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
    // lastRole is intentionally NOT reset here — it's what tells the
    // login screen which tab (Admin/User) to reopen on.
    role = 'Admin';
    employeeId = null;
    error = null;
    notifyListeners();
  }
}
