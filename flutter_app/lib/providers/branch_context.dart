import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import '../services/dio_client.dart';

/// Global branch selection used by Dashboard, Exams, Expenses and Vouchers.
/// The selected branch is always one active branch when branches exist.
class BranchContext extends ChangeNotifier {
  static const _selectedBranchKey = 'selected_branch_id';

  final DioClient api = DioClient();
  List<Branch> branches = [];
  int? selectedBranchId;

  Future<void>? _loadFuture;

  Branch? get selectedBranch {
    final id = selectedBranchId;
    if (id == null) return null;
    for (final b in branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  String get selectedBranchName => selectedBranch?.name ?? 'All Branches';

  Future<void> ensureLoaded() => _loadFuture ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getInt(_selectedBranchKey);
      final response = await api.branches(status: 'Active');
      branches = (response.data['data'] as List? ?? const [])
          .map((e) => Branch.fromMap(Map<String, dynamic>.from(e)))
          .where((b) => b.status.isEmpty || b.status.toLowerCase() == 'active')
          .toList();

      if (savedId != null && branches.any((b) => b.id == savedId)) {
        selectedBranchId = savedId;
      } else if (branches.isNotEmpty) {
        selectedBranchId = branches.first.id;
        await prefs.setInt(_selectedBranchKey, selectedBranchId!);
      } else {
        selectedBranchId = null;
        await prefs.remove(_selectedBranchKey);
      }
      notifyListeners();
    } catch (e) {
      // Keep the app usable even when branch lookup temporarily fails.
      if (kDebugMode) debugPrint('BranchContext load failed: $e');
    }
  }

  Future<void> selectBranch(int? id) async {
    if (id == null || !branches.any((b) => b.id == id)) return;
    if (selectedBranchId == id) return;

    selectedBranchId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedBranchKey, id);
    notifyListeners();
  }

  Future<void> refreshBranches() async {
    _loadFuture = _load();
    await _loadFuture;
  }
}
