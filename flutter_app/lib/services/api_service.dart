import 'package:dio/dio.dart';
import 'dio_client.dart';

/// High-level API facade. Screens should prefer this service instead of
/// constructing raw HTTP requests.
class ApiService {
  final DioClient client = DioClient();

  Future<Response> dashboard({int? branchId}) => client.dashboard(branchId: branchId);
  Future<Response> branches({String? q, String? status}) =>
      client.branches(q: q, status: status);
  Future<Response> createBranch(Map<String, dynamic> data) => client.createBranch(data);
  Future<Response> updateBranch(int id, Map<String, dynamic> data) =>
      client.updateBranch(id, data);
  Future<Response> deactivateBranch(int id) => client.deactivateBranch(id);
  Future<Response> examTypes() => client.examTypes();
  Future<Response> sessions({int? branchId, String? status}) =>
      client.sessions(branchId: branchId, status: status);
  Future<Response> candidates({String? q, int? branchId}) =>
      client.candidates(q: q, branchId: branchId);
  Future<Response> expenses({int? branchId, String? q, String? status}) =>
      client.expenses(branchId: branchId, q: q, status: status);
  Future<Response> expenseCategories() => client.expenseCategories();
  Future<Response> createExpense(Map<String, dynamic> data) => client.createExpense(data);
  Future<Response> invoices({int? branchId, String? q, String? status}) =>
      client.invoices(branchId: branchId, q: q, status: status);
  Future<Response> createInvoice(Map<String, dynamic> data) => client.createInvoice(data);
  Future<Response> updateInvoice(int id, Map<String, dynamic> data) => client.updateInvoice(id, data);
  Future<Response> deleteInvoice(int id) => client.deleteInvoice(id);
}
