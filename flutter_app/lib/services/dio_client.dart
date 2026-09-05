import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio dio;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final p = await SharedPreferences.getInstance();
          final token = p.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            try {
              final p = await SharedPreferences.getInstance();
              final refresh = p.getString('refresh_token');
              if (refresh != null && refresh.isNotEmpty) {
                final refreshDio =
                    Dio(BaseOptions(baseUrl: ApiConfig.apiBaseUrl));
                final r = await refreshDio.post(
                  ApiConfig.refreshPath,
                  options: Options(
                    headers: {'Authorization': 'Bearer $refresh'},
                  ),
                );
                final newToken = r.data['data']?['access'];
                if (newToken != null) {
                  await p.setString('access_token', newToken.toString());
                  final opts = error.requestOptions;
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  final cloneReq = await dio.fetch(opts);
                  return handler.resolve(cloneReq);
                }
              }
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<Response> login(String username, String password) =>
      dio.post(
        ApiConfig.loginPath,
        data: {
          'username': username,
          'password': password,
        },
      );

  Future<Response> me() => dio.get(ApiConfig.mePath);

  Future<Response> dashboard({int? branchId}) => dio.get(
        ApiConfig.dashboardPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> branches({String? q, String? status}) => dio.get(
        ApiConfig.branchesPath,
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

  Future<Response> createBranch(Map<String, dynamic> data) =>
      dio.post(ApiConfig.branchesPath, data: data);

  Future<Response> updateBranch(
    int id,
    Map<String, dynamic> data,
  ) =>
      dio.put('${ApiConfig.branchesPath}$id/', data: data);

  Future<Response> deleteBranch(int id) =>
      dio.delete('${ApiConfig.branchesPath}$id/');

  Future<Response> patchBranchStatus(
    int id, {
    String? status,
  }) =>
      dio.patch(
        '${ApiConfig.branchesPath}$id/status/',
        data: {
          if (status != null) 'status': status,
        },
      );

  Future<Response> deactivateBranch(int id) =>
      dio.delete('${ApiConfig.branchesPath}$id/');

  Future<Response> examTypes() => dio.get(ApiConfig.examTypesPath);

  Future<Response> branchMappings({int? branchId}) => dio.get(
        ApiConfig.branchMappingsPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> sessions({
    int? branchId,
    String? status,
  }) =>
      dio.get(
        ApiConfig.sessionsPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
          if (status != null && status.isNotEmpty) 'status': status,
        },
      );

  Future<Response> attendedHistory({
    String? date,
    String? month,
    String? dateFrom,
    String? dateTo,
    int? branchId,
    int? examTypeId,
    String? q,
  }) =>
      dio.get(
        ApiConfig.attendedHistoryPath,
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
          if (month != null && month.isNotEmpty) 'month': month,
          if (dateFrom != null && dateFrom.isNotEmpty)
            'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
          if (branchId != null) 'branch_id': branchId,
          if (examTypeId != null) 'exam_type_id': examTypeId,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        },
      );

  Future<Response> candidates({
    String? q,
    int? branchId,
    int? teamId,
  }) =>
      dio.get(
        ApiConfig.candidatesPath,
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (branchId != null) 'branch_id': branchId,
          if (teamId != null) 'team_id': teamId,
        },
      );

  Future<Response> teams({
    String? q,
    int? examTypeId,
    String? status,
    int? branchId,
  }) =>
      dio.get(
        ApiConfig.teamsPath,
        queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (examTypeId != null) 'exam_type_id': examTypeId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> createTeam(Map<String, dynamic> data) =>
      dio.post(ApiConfig.teamsPath, data: data);

  Future<Response> updateTeam(
    int id,
    Map<String, dynamic> data,
  ) =>
      dio.put('${ApiConfig.teamsPath}$id/', data: data);

  Future<Response> deleteTeam(int id) =>
      dio.delete('${ApiConfig.teamsPath}$id/');

  Future<Response> teamReport(int id) =>
      dio.get('${ApiConfig.teamsPath}$id/report/');

  Future<Response> examDashboard({int? branchId}) => dio.get(
        ApiConfig.examDashboardPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> expenses({
    int? branchId,
    int? categoryId,
    String? paymentMode,
    String? status,
    String? q,
    String? dateFrom,
    String? dateTo,
  }) =>
      dio.get(
        ApiConfig.expensesPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
          if (categoryId != null) 'category_id': categoryId,
          if (paymentMode != null &&
              paymentMode.isNotEmpty &&
              paymentMode != 'All' &&
              paymentMode != 'All Payment Modes')
            'payment_mode': paymentMode,
          if (status != null &&
              status.isNotEmpty &&
              status != 'All')
            'status': status,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (dateFrom != null && dateFrom.isNotEmpty)
            'date_from': dateFrom,
          if (dateTo != null && dateTo.isNotEmpty) 'date_to': dateTo,
        },
      );

  Future<Response> employees({
    int? branchId,
    String? status,
    String? q,
  }) =>
      dio.get(
        ApiConfig.employeesPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        },
      );

  Future<Response> employee(int id) =>
      dio.get('${ApiConfig.employeesPath}$id/');

  Future<Response> createEmployee(Map<String, dynamic> data) =>
      dio.post(ApiConfig.employeesPath, data: data);

  Future<Response> updateEmployee(
    int id,
    Map<String, dynamic> data,
  ) =>
      dio.put('${ApiConfig.employeesPath}$id/', data: data);

  Future<Response> deleteEmployee(int id) =>
      dio.delete('${ApiConfig.employeesPath}$id/');

  Future<Response> employeeSalaryHistory(
    int id, {
    int? branchId,
  }) =>
      dio.get(
        '${ApiConfig.employeesPath}$id/salary-history/',
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> expenseCategories() =>
      dio.get(ApiConfig.expenseCategoriesPath);

  Future<Response> createExpenseCategory(String name) =>
      dio.post(
        ApiConfig.expenseCategoriesPath,
        data: {'name': name},
      );

  Future<Response> toggleExpenseCategory(
    int id, {
    String? status,
  }) =>
      dio.post(
        '${ApiConfig.expenseCategoriesPath}$id/toggle/',
        data: {
          if (status != null) 'status': status,
        },
      );

  Future<Response> expenseBudgets() =>
      dio.get(ApiConfig.expenseBudgetsPath);

  Future<Response> invoices({
    int? branchId,
    String? q,
    String? status,
  }) =>
      dio.get(
        ApiConfig.expenseInvoicesPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (status != null &&
              status.isNotEmpty &&
              status != 'All')
            'status': status,
        },
      );

  Future<Response> createInvoice(Map<String, dynamic> data) =>
      dio.post(ApiConfig.expenseInvoicesPath, data: data);

  Future<Response> updateInvoice(
    int id,
    Map<String, dynamic> data,
  ) =>
      dio.put('${ApiConfig.expenseInvoicesPath}$id/', data: data);

  Future<Response> deleteInvoice(int id) =>
      dio.delete('${ApiConfig.expenseInvoicesPath}$id/');

  Future<Response> createExpense(Map<String, dynamic> data) =>
      dio.post(ApiConfig.expensesPath, data: data);

  Future<Response> updateExpense(
    int id,
    Map<String, dynamic> data,
  ) =>
      dio.put('${ApiConfig.expensesPath}$id/', data: data);

  Future<Response> deleteExpense(int id) =>
      dio.delete('${ApiConfig.expensesPath}$id/');

  Future<Response> vouchers({
    int? branchId,
    String? status,
    String? q,
  }) =>
      dio.get(
        ApiConfig.vouchersPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
          if (status != null && status.isNotEmpty) 'status': status,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        },
      );

  Future<Response> voucherDashboard({int? branchId}) => dio.get(
        ApiConfig.voucherDashboardPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> purchaseVouchers(
    Map<String, dynamic> data,
  ) =>
      dio.post(
        ApiConfig.voucherPurchasePath,
        data: data,
      );

  // Used by invoice_tab.dart for voucher purchase invoice/history data.
  // This does not change the existing purchaseVouchers() POST operation.
  Future<Response> voucherPurchaseInvoices({
    int? branchId,
  }) =>
      dio.get(
        ApiConfig.voucherHistoryPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> assignVoucher(
    int id,
    Map<String, dynamic> data,
  ) =>
      dio.post(
        '${ApiConfig.vouchersPath}$id/assign/',
        data: data,
      );

  Future<Response> sellVoucher(
    Map<String, dynamic> data,
  ) =>
      dio.post(
        ApiConfig.voucherSellPath,
        data: data,
      );

  Future<Response> voucherStudents() =>
      dio.get(ApiConfig.voucherStudentsPath);

  Future<Response> voucherHistory({int? branchId}) =>
      dio.get(
        ApiConfig.voucherHistoryPath,
        queryParameters: {
          if (branchId != null) 'branch_id': branchId,
        },
      );

  Future<Response> voucherDetails(int id) =>
      dio.get('${ApiConfig.vouchersPath}$id/details/');

  Future<Response> useVoucher(int id) =>
      dio.post('${ApiConfig.vouchersPath}$id/use/');

  Future<Response> createCandidate(
    Map<String, dynamic> data,
  ) =>
      dio.post(
        ApiConfig.candidatesPath,
        data: data,
      );

  Future<Response> updateCandidateStatus(
    int id,
    String status,
  ) =>
      dio.patch(
        '${ApiConfig.candidatesPath}$id/',
        data: {'status': status},
      );

  Future<Response> createSession(
    Map<String, dynamic> data,
  ) =>
      dio.post(
        ApiConfig.sessionsPath,
        data: data,
      );

  Future<Response> createExamType(
    Map<String, dynamic> data,
  ) =>
      dio.post(
        ApiConfig.examTypesPath,
        data: data,
      );

  Future<Response> createBranchMapping(
    Map<String, dynamic> data,
  ) =>
      dio.post(
        ApiConfig.branchMappingsPath,
        data: data,
      );

  Future<void> saveTokens(
    Map<String, dynamic> tokens,
  ) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'access_token',
      '${tokens['access']}',
    );

    if (tokens['refresh'] != null) {
      await p.setString(
        'refresh_token',
        '${tokens['refresh']}',
      );
    }
  }

  Future<void> clearTokens() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('access_token');
    await p.remove('refresh_token');
  }

  Future<String?> readAccessToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('access_token');
  }

  Future<String?> readRefreshToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString('refresh_token');
  }
}
