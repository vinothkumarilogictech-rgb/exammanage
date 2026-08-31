import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// Build with:
  /// - Android emulator: flutter run --dart-define=API_SERVER_URL=http://10.0.2.2:5000
  /// - Chrome/web (flutter run -d chrome): no flag needed, defaults to localhost:5000
  /// - iOS simulator: flutter run --dart-define=API_SERVER_URL=http://localhost:5000
  /// - Real phone: flutter run --dart-define=API_SERVER_URL=http://YOUR-PC-LAN-IP:5000
  ///
  /// 10.0.2.2 is a special alias that ONLY exists inside the Android
  /// emulator's virtual network - it is unreachable from Chrome/web,
  /// iOS simulator, or a real device, and was the cause of "Unable to
  /// connect to the Office Management API." when testing in Chrome.
  ///
  /// The API itself is mounted at /api/v1.
  static const String _dartDefineUrl = String.fromEnvironment('API_SERVER_URL');
  static String get baseUrl {
    if (_dartDefineUrl.isNotEmpty) return _dartDefineUrl;
    if (kIsWeb) {
      // Keep the API on the same hostname the browser used to open the
      // Flutter app. This avoids localhost/127.0.0.1 and IPv4/IPv6
      // hostname mismatches during local Flutter Web development.
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : '127.0.0.1';
      return 'http://$host:5000';
    }
    return 'http://10.0.2.2:5000';
  }

  static const String apiBasePath = '/api/v1';
  static String get apiBaseUrl => '$baseUrl$apiBasePath';

  static const String loginPath = '/auth/login/';
  static const String refreshPath = '/auth/refresh/';
  static const String mePath = '/auth/me/';
  static const String dashboardPath = '/dashboard/';
  static const String attendedHistoryPath = '/exams/attended-history/';
  static const String branchesPath = '/branches/';
  static const String examTypesPath = '/exams/types/';
  static const String branchMappingsPath = '/exams/branch-mappings/';
  static const String sessionsPath = '/exams/sessions/';
  static const String candidatesPath = '/exams/candidates/';
  static const String teamsPath = '/exams/teams/';
  static const String examDashboardPath = '/exams/dashboard/';
  static const String expensesPath = '/expenses/';
  static const String expenseCategoriesPath = '/expenses/categories/';
  static const String expenseBudgetsPath = '/expenses/budgets/';
  static const String vouchersPath = '/vouchers/';
  static const String voucherDashboardPath = '/vouchers/dashboard/';
  static const String voucherPurchasePath = '/vouchers/purchase/';
  static const String voucherSellPath = '/vouchers/sell/';
  static const String voucherStudentsPath = '/vouchers/students/';
  static const String voucherHistoryPath = '/vouchers/history/';
}
