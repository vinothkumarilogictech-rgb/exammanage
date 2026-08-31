import 'dio_client.dart';

class DataSyncService {
  final DioClient api = DioClient();

  Future<Map<String, dynamic>> refreshDashboard({int? branchId}) async {
    final r = await api.dashboard(branchId: branchId);
    return Map<String, dynamic>.from(r.data['data'] ?? {});
  }

  Future<List<Map<String, dynamic>>> branches({String? q}) async {
    final r = await api.branches(q: q);
    return List<Map<String, dynamic>>.from(
      (r.data['data'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e)),
    );
  }

  Future<List<Map<String, dynamic>>> expenses({int? branchId, String? q}) async {
    final r = await api.expenses(branchId: branchId, q: q);
    return List<Map<String, dynamic>>.from(
      (r.data['data'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e)),
    );
  }
}
