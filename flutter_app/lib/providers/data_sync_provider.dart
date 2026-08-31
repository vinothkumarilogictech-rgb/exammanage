import 'package:flutter/foundation.dart';
import '../services/data_sync_service.dart';

class DataSyncProvider extends ChangeNotifier {
  final DataSyncService service = DataSyncService();
  bool loading = false;
  Map<String, dynamic> dashboard = {};
  String? error;

  Future<void> refresh({int? branchId}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      dashboard = await service.refreshDashboard(branchId: branchId);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
