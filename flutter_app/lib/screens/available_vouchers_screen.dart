import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';

class AvailableVouchersScreen extends StatefulWidget {
  const AvailableVouchersScreen({super.key});

  @override
  State<AvailableVouchersScreen> createState() => _AvailableVouchersScreenState();
}

class _AvailableVouchersScreenState extends State<AvailableVouchersScreen> {
  final api = DioClient();
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> vouchers = [];
  late final BranchContext _branchContext;

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    load();
  }

  void _onBranchChanged() {
    if (!mounted) return;
    load();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    super.dispose();
  }

  Future<void> load() async {
    await _branchContext.ensureLoaded();
    final branchId = _branchContext.selectedBranchId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await api.vouchers(branchId: branchId, status: 'Available');
      vouchers = (response.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((v) => v['status'] == 'Available')
          .toList();
    } catch (e) {
      error = 'Failed to load available vouchers: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  String money(dynamic value) {
    final n = double.tryParse('${value ?? 0}') ?? 0;
    return '₹${n.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: AppBarStyle.gradientDecoration()),
        title: const Text('Available Vouchers', style: AppBarStyle.titleStyle),
        actions: [
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(message: error!, onRetry: load)
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Available Voucher IDs',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration:
                                BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(20)),
                            child: Text('${vouchers.length}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (vouchers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration:
                                    const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                                child: Icon(Icons.confirmation_num_outlined, size: 26, color: Colors.grey.shade400),
                              ),
                              const SizedBox(height: 14),
                              Text('No vouchers available. Purchase a new batch to add stock.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
                            ],
                          ),
                        )
                      else
                        ...vouchers.map((v) => _voucherTile(v)),
                    ],
                  ),
                ),
    );
  }

  Widget _voucherTile(Map<String, dynamic> v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.confirmation_num_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                      child: Text('${v['voucher_code'] ?? '-'}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                  if (v['exam_type_name'] != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Text('${v['exam_type_name']}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('Available for sale', style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5)),
                const SizedBox(height: 3),
                Text('Purchase cost ${money(v['purchase_cost'])}',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
