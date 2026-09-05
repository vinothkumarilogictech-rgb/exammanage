import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  /// API_SERVER_URL may be supplied without /api/v1, for example:
  ///
  /// Android emulator:
  /// flutter run --dart-define=API_SERVER_URL=http://10.0.2.2:5000
  ///
  /// Chrome/web:
  /// no flag needed; defaults to http://localhost:5000
  ///
  /// Real phone:
  /// flutter run --dart-define=API_SERVER_URL=http://YOUR-PC-LAN-IP:5000
  static const String _dartDefineUrl =
      String.fromEnvironment('API_SERVER_URL');

  static const String baseUrl = 'http://localhost:5001';

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
  static const String employeesPath = '/employees/';
  static const String expenseCategoriesPath = '/expenses/categories/';
  static const String expenseBudgetsPath = '/expenses/budgets/';
  static const String expenseInvoicesPath = '/expenses/invoices/';
  static const String vouchersPath = '/vouchers/';
  static const String voucherDashboardPath = '/vouchers/dashboard/';
  static const String voucherPurchasePath = '/vouchers/purchase/';
  static const String voucherSellPath = '/vouchers/sell/';
  static const String voucherStudentsPath = '/vouchers/students/';
  static const String voucherHistoryPath = '/vouchers/history/';
}
