import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';
import 'package:provider/provider.dart';

class AvailableVouchersScreen extends StatefulWidget {
  const AvailableVouchersScreen({super.key});

  @override
  State<AvailableVouchersScreen> createState() => _AvailableVouchersScreenState();
}

class _AvailableVouchersScreenState extends State<AvailableVouchersScreen> {
  final api = DioClient();
  late final BranchContext _branchContext;
  bool loading = true;
  List<Map<String, dynamic>> vouchers = [];

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_reloadForBranch);
    load();
  }

  void _reloadForBranch() {
    if (mounted) load();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_reloadForBranch);
    super.dispose();
  }

  Future<void> load() async {
    await _branchContext.ensureLoaded();
    final branchId = _branchContext.selectedBranchId;
    if (mounted) setState(() => loading = true);
    try {
      final response = await api.vouchers(branchId: branchId, status: 'Available');
      vouchers = (response.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((v) => '${v['status'] ?? ''}'.toLowerCase() == 'available')
          .toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Available voucher load failed: $e')),
        );
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Map<String, List<Map<String, dynamic>>> _groupByExam() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final voucher in vouchers) {
      final exam = '${voucher['exam_type_name'] ?? 'Unassigned Exam'}'.trim();
      final name = exam.isEmpty ? 'Unassigned Exam' : exam;
      groups.putIfAbsent(name, () => []).add(voucher);
    }
    final sorted = Map<String, List<Map<String, dynamic>>>.fromEntries(
      groups.entries.toList()..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
    );
    return sorted;
  }

  String money(dynamic value) {
    final n = double.tryParse('${value ?? 0}') ?? 0;
    return '₹${n.toStringAsFixed(2)}';
  }

  String dateTime(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return '-';
    final d = DateTime.tryParse('$value')?.toLocal();
    if (d == null) return '$value';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _showVoucherDetails(Map<String, dynamic> voucher) async {
    try {
      final response = await api.voucherDetails(voucher['id']);
      final data = Map<String, dynamic>.from(response.data['data'] ?? {});
      if (!mounted) return;
      _detailSheet(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load voucher details: $e')),
      );
    }
  }

  void _detailSheet(Map<String, dynamic> data) {
    final v = Map<String, dynamic>.from(data['voucher'] ?? {});
    final purchase = Map<String, dynamic>.from(data['purchase'] ?? {});
    final history = (data['history'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .9),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ListView(
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.confirmation_num_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${v['voucher_code'] ?? '-'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    _statusChip('${v['status'] ?? 'Available'}'),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _section('Voucher Details', [
              _detail('Voucher Code', '${v['voucher_code'] ?? '-'}'),
              _detail('Exam', '${v['exam_type_name'] ?? '-'}'),
              _detail('Status', '${v['status'] ?? '-'}'),
              _detail('Batch', '${purchase['batch_number'] ?? v['batch_number'] ?? '-'}'),
              _detail('Purchase Date', '${purchase['purchase_date'] ?? '-'}'),
              _detail('Purchase Cost', money(v['purchase_cost'])),
              _detail('Selling Price', money(v['selling_price'])),
              _detail('Branch', '${purchase['branch_name'] ?? v['branch_name'] ?? '-'}'),
            ]),
            if ((v['notes'] ?? '').toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _section('Notes', [_detail('Notes', '${v['notes']}')]),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: 12),
              _section('Sale History', history.map((h) => _detail(
                '${h['student_name'] ?? 'Sale'}',
                '${dateTime(h['sold_at'])} • ${money(h['final_amount'])}',
              )).toList()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 118, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }

  Widget _statusChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(color: Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.w800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByExam();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        title: const Text('Available Vouchers', style: AppBarStyle.titleStyle),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: load,
              child: groups.isEmpty
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                      const SizedBox(height: 160),
                      Icon(Icons.inventory_2_outlined, size: 58, color: Colors.grey),
                      const SizedBox(height: 12),
                      Center(child: Text('No available vouchers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey))),
                    ])
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                      children: [
                        Text('${vouchers.length} available vouchers', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ...groups.entries.map((entry) => _examCard(entry.key, entry.value)),
                      ],
                    ),
            ),
    );
  }

  Widget _examCard(String exam, List<Map<String, dynamic>> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9D5FF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ExamVoucherListScreen(examName: exam, vouchers: rows))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.school_rounded, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(exam, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('${rows.length} vouchers', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ExamVoucherListScreen extends StatelessWidget {
  final String examName;
  final List<Map<String, dynamic>> vouchers;

  const _ExamVoucherListScreen({required this.examName, required this.vouchers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 3,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        title: Text(examName, style: AppBarStyle.titleStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
        children: [
          Text('${vouchers.length} available vouchers', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...vouchers.map((v) => _AvailableVoucherTile(voucher: v)),
        ],
      ),
    );
  }
}

class _AvailableVoucherTile extends StatelessWidget {
  final Map<String, dynamic> voucher;
  const _AvailableVoucherTile({required this.voucher});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        leading: Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.confirmation_num_outlined, color: AppColors.primary)),
        title: Text('${voucher['voucher_code'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Selling price: ₹${double.tryParse('${voucher['selling_price'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openDetails(context),
      ),
    );
  }

  Future<void> _openDetails(BuildContext context) async {
    try {
      final api = DioClient();
      final response = await api.voucherDetails(voucher['id']);
      final data = Map<String, dynamic>.from(response.data['data'] ?? {});
      if (!context.mounted) return;
      final v = Map<String, dynamic>.from(data['voucher'] ?? {});
      final p = Map<String, dynamic>.from(data['purchase'] ?? {});
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .85),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: ListView(children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Text('${v['voucher_code'] ?? '-'}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _row('Exam', '${v['exam_type_name'] ?? '-'}'),
            _row('Status', '${v['status'] ?? '-'}'),
            _row('Batch', '${p['batch_number'] ?? '-'}'),
            _row('Supplier', '${p['supplier'] ?? '-'}'),
            _row('Purchase Date', '${p['purchase_date'] ?? '-'}'),
            _row('Purchase Cost', '₹${double.tryParse('${v['purchase_cost'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}'),
            _row('Selling Price', '₹${double.tryParse('${v['selling_price'] ?? 0}')?.toStringAsFixed(2) ?? '0.00'}'),
            _row('Branch', '${v['branch_name'] ?? p['branch_name'] ?? '-'}'),
          ]),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to load voucher details: $e')));
    }
  }

  static Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );
}
