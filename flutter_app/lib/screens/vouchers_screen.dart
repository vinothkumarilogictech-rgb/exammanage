import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../app_theme.dart';
import '../widgets/common.dart';
import '../services/dio_client.dart';
import '../services/pdf_report_kit.dart';
import '../providers/branch_context.dart';
import 'package:provider/provider.dart';
import 'profile_screen.dart';

class VouchersScreen extends StatefulWidget {
  final int initialTab;

  const VouchersScreen({super.key, this.initialTab = 0})
    : assert(initialTab >= 0 && initialTab < 3);

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen>
    with SingleTickerProviderStateMixin {
  final api = DioClient();
  late TabController _tabs;
  bool loading = true;
  bool saving = false;
  Map<String, dynamic> stats = {};
  List<Map<String, dynamic>> vouchers = [];
  List<Map<String, dynamic>> history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  DateTime? _selectedHistoryDate;
  late final BranchContext _branchContext;

  // Available Exam Types for filters
  List<String> _availableExamTypes = [];

  // Sold Vouchers Filtering state
  final TextEditingController _soldCandidateCtrl = TextEditingController();
  String _soldCandidateFilter = '';
  String? _soldSelectedExamType;
  List<Map<String, dynamic>> _filteredSold = [];

  // History Filtering state
  final TextEditingController _historyCandidateCtrl = TextEditingController();
  String _historyCandidateFilter = '';
  String? _historySelectedExamType;

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    load();
  }

  void _onBranchChanged() {
    if (!mounted) return;
    load();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    _tabs.dispose();
    _soldCandidateCtrl.dispose();
    _historyCandidateCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    await _branchContext.ensureLoaded();
    final branchId = _branchContext.selectedBranchId;
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait([
        api.voucherDashboard(branchId: branchId),
        api.vouchers(branchId: branchId),
        api.voucherHistory(branchId: branchId),
        api.examTypes(),
      ]);
      stats = Map<String, dynamic>.from(results[0].data['data'] ?? {});
      vouchers = (results[1].data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      history = (results[2].data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final examTypeSet = <String>{};
      for (final v in vouchers) {
        final et = '${v['exam_type_name'] ?? v['exam_type'] ?? ''}'.trim();
        if (et.isNotEmpty) examTypeSet.add(et);
      }
      for (final h in history) {
        final et = '${h['exam_type_name'] ?? h['exam_type'] ?? ''}'.trim();
        if (et.isNotEmpty) examTypeSet.add(et);
      }
      final etList = (results[3].data['data'] as List? ?? []);
      for (final item in etList) {
        final n = '${item['name'] ?? ''}'.trim();
        if (n.isNotEmpty) examTypeSet.add(n);
      }
      final sortedTypes = examTypeSet.toList()..sort();
      _availableExamTypes = sortedTypes;

      _applySoldFilter();
      _applyHistoryFilter();
    } catch (e) {
      if (mounted) _toast('Voucher data load failed: $e', error: true);
    }
    if (mounted) setState(() => loading = false);
  }

  String money(dynamic value) {
    final n = double.tryParse('${value ?? 0}') ?? 0;
    return '₹${n.toStringAsFixed(2)}';
  }

  String dateTime(dynamic value) {
    if (value == null || '$value'.isEmpty) return '-';
    final d = DateTime.tryParse('$value')?.toLocal();
    if (d == null) return '$value';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppColors.red : AppColors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C1FB0), Color(0xFF9A22C7), Color(0xFFE0189E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x559A22C7),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
        ),
        title: const Text('Voucher', style: AppBarStyle.titleStyle),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            icon: const Icon(Icons.person_rounded),
          ),
          IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabs,
              indicator: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Sold'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF5F0FF),
                    Color(0xFFFFF8FC),
                    Color(0xFFF1F5FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: load,
                child: TabBarView(
                  controller: _tabs,
                  children: [_overview(), _soldTab(), _historyTab()],
                ),
              ),
            ),
    );
  }

  // ================================================================
  // OVERVIEW TAB
  // ================================================================

  Widget _overview() {
    final available = vouchers
        .where((v) => v['status'] == 'Available')
        .toList();
    final sold = vouchers
        .where((v) => ['Sold', 'Assigned', 'Used'].contains(v['status']))
        .toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            _VoucherKpiCard(
              title: 'Available',
              value: '${stats['available'] ?? available.length}',
              icon: Icons.inventory_2_rounded,
              tint: const Color(0xFFEDE9FE),
              iconColor: AppColors.primary,
            ),
            _VoucherKpiCard(
              title: 'Sold',
              value: '${stats['issued'] ?? sold.length}',
              icon: Icons.person_rounded,
              tint: const Color(0xFFDBEAFE),
              iconColor: AppColors.blue,
            ),
            _VoucherKpiCard(
              title: 'Sales',
              value: money(stats['sales_revenue']),
              icon: Icons.payments_rounded,
              tint: const Color(0xFFDCFCE7),
              iconColor: AppColors.green,
            ),
            _VoucherKpiCard(
              title: 'Profit',
              value: money(stats['realized_profit']),
              icon: Icons.trending_up_rounded,
              tint: const Color(0xFFFEF3C7),
              iconColor: AppColors.orange,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _VoucherQuickAction(
                icon: Icons.add_card_rounded,
                title: 'Sell',
                gradientColors: const [Color(0xFF9A22C7), AppColors.primary],
                onTap: _showSellVoucher,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VoucherQuickAction(
                icon: Icons.inventory_rounded,
                title: 'Bulk Purchase',
                gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                onTap: _showPurchase,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _VoucherSectionCard(
          title: 'Stock Summary',
          icon: Icons.bar_chart_rounded,
          child: Column(
            children: [
              _summaryLine(
                'Purchase Cost',
                money(stats['purchase_cost']),
                Icons.shopping_bag_outlined,
              ),
              _summaryLine(
                'Available Stock Value',
                money(stats['stock_value']),
                Icons.account_balance_wallet_outlined,
              ),
              _summaryLine(
                'Total Purchased',
                '${stats['purchased'] ?? 0} vouchers',
                Icons.inventory_2_outlined,
              ),
              _summaryLine(
                'Total Sales',
                '${stats['sale_count'] ?? history.length} sales',
                Icons.receipt_long_outlined,
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Available Voucher IDs',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDE9FE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${available.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (available.isEmpty)
          _empty('No vouchers available. Purchase a new batch to add stock.')
        else
          ...available.take(20).map((v) => _voucherTile(v, allowSell: true)),
        if (available.length > 20)
          Center(
            child: TextButton(
              onPressed: () =>
                  _showVoucherList('Available Vouchers', available),
              child: Text('View all ${available.length} available vouchers'),
            ),
          ),
      ],
    );
  }

  Widget _summaryLine(
    String label,
    String value,
    IconData icon, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade500),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SOLD TAB
  // ================================================================

  void _applySoldFilter() {
    final allSold = vouchers
        .where((v) => ['Sold', 'Assigned', 'Used'].contains(v['status']))
        .toList();

    _filteredSold = allSold.where((v) {
      // 1. Candidate Name filter
      if (_soldCandidateFilter.trim().isNotEmpty) {
        final query = _soldCandidateFilter.trim().toLowerCase();
        final name = '${v['student_name'] ?? v['candidate_name'] ?? ''}'.toLowerCase();
        final mobile = '${v['student_mobile'] ?? v['mobile'] ?? ''}'.toLowerCase();
        final code = '${v['voucher_code'] ?? ''}'.toLowerCase();
        if (!name.contains(query) && !mobile.contains(query) && !code.contains(query)) {
          return false;
        }
      }

      // 2. Exam Type filter
      if (_soldSelectedExamType != null &&
          _soldSelectedExamType!.isNotEmpty &&
          _soldSelectedExamType != 'All') {
        final et = '${v['exam_type_name'] ?? v['exam_type'] ?? ''}'.trim().toLowerCase();
        if (et != _soldSelectedExamType!.trim().toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  void _clearSoldFilter() {
    setState(() {
      _soldCandidateCtrl.clear();
      _soldCandidateFilter = '';
      _soldSelectedExamType = null;
      _applySoldFilter();
    });
  }

  Widget _soldFilterBar() {
    final hasActiveFilter = _soldCandidateFilter.isNotEmpty ||
        (_soldSelectedExamType != null && _soldSelectedExamType != 'All');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasActiveFilter ? const Color(0xFFC4B5FD) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Filter Sold Vouchers',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              if (hasActiveFilter)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF6C1FB0),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _soldCandidateCtrl,
            decoration: InputDecoration(
              hintText: 'Candidate name, mobile, or voucher...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF6C1FB0)),
              suffixIcon: _soldCandidateCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _soldCandidateCtrl.clear();
                        setState(() {
                          _soldCandidateFilter = '';
                          _applySoldFilter();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {});
            },
            onSubmitted: (val) {
              setState(() {
                _soldCandidateFilter = val.trim();
                _applySoldFilter();
              });
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _soldSelectedExamType,
            decoration: InputDecoration(
              hintText: 'Select Exam Type (All)',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.school_outlined, size: 20, color: Color(0xFF6C1FB0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Exam Types', style: TextStyle(fontSize: 13)),
              ),
              ..._availableExamTypes.map(
                (et) => DropdownMenuItem<String>(
                  value: et,
                  child: Text(et, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _soldSelectedExamType = val;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _soldCandidateFilter = _soldCandidateCtrl.text.trim();
                      _applySoldFilter();
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C1FB0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Apply Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearSoldFilter,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _soldTab() {
    final allSold = vouchers
        .where((v) => ['Sold', 'Assigned', 'Used'].contains(v['status']))
        .toList();
    final hasFilter = _soldCandidateFilter.isNotEmpty ||
        (_soldSelectedExamType != null && _soldSelectedExamType != 'All');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sold Vouchers',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              hasFilter
                  ? '${_filteredSold.length} of ${allSold.length}'
                  : '${allSold.length} total',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _soldFilterBar(),
        const SizedBox(height: 14),
        if (allSold.isEmpty)
          _empty('No vouchers have been sold yet.')
        else if (_filteredSold.isEmpty)
          _empty('No sold vouchers match your filter criteria.')
        else
          ..._filteredSold.map((v) => _voucherTile(v)),
      ],
    );
  }

  // ================================================================
  // HISTORY TAB
  // ================================================================

  DateTime? _parseHistoryDate(dynamic value) {
    if (value == null || '$value'.trim().isEmpty) return null;
    try {
      return DateTime.parse('$value').toLocal();
    } catch (_) {
      return null;
    }
  }

  String _historyDateLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]}';
  }

  void _applyHistoryFilter() {
    _filteredHistory = history.where((h) {
      // 1. Date filter (keeps existing date filtering)
      if (_selectedHistoryDate != null) {
        final soldAt = _parseHistoryDate(h['sold_at']);
        if (soldAt == null) return false;
        final saleDay = DateTime(soldAt.year, soldAt.month, soldAt.day);
        final selected = DateTime(
          _selectedHistoryDate!.year,
          _selectedHistoryDate!.month,
          _selectedHistoryDate!.day,
        );
        if (saleDay != selected) return false;
      }

      // 2. Candidate Name filter
      if (_historyCandidateFilter.trim().isNotEmpty) {
        final query = _historyCandidateFilter.trim().toLowerCase();
        final name = '${h['student_name'] ?? h['candidate_name'] ?? ''}'.toLowerCase();
        final mobile = '${h['mobile'] ?? h['student_mobile'] ?? ''}'.toLowerCase();
        final code = '${h['voucher_code'] ?? ''}'.toLowerCase();
        if (!name.contains(query) && !mobile.contains(query) && !code.contains(query)) {
          return false;
        }
      }

      // 3. Exam Type filter
      if (_historySelectedExamType != null &&
          _historySelectedExamType!.isNotEmpty &&
          _historySelectedExamType != 'All') {
        final et = '${h['exam_type_name'] ?? h['exam_type'] ?? ''}'.trim().toLowerCase();
        if (et != _historySelectedExamType!.trim().toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _pickHistoryFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedHistoryDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'FILTER VOUCHER SALES BY DATE',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedHistoryDate = DateTime(picked.year, picked.month, picked.day);
      _applyHistoryFilter();
    });
  }

  void _clearHistoryFilterDate() {
    if (_selectedHistoryDate == null) return;
    setState(() {
      _selectedHistoryDate = null;
      _applyHistoryFilter();
    });
  }

  void _clearHistoryFilters() {
    setState(() {
      _selectedHistoryDate = null;
      _historyCandidateCtrl.clear();
      _historyCandidateFilter = '';
      _historySelectedExamType = null;
      _applyHistoryFilter();
    });
  }

  Future<void> _showHistoryExportOptions(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Export Sales History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFB91C1C),
                ),
              ),
              title: const Text(
                'PDF',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Download as a PDF document'),
              onTap: () {
                Navigator.pop(ctx);
                _exportHistoryPdf();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF047857),
                ),
              ),
              title: const Text(
                'Excel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Download as a spreadsheet (CSV)'),
              onTap: () {
                Navigator.pop(ctx);
                _exportHistoryExcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportHistoryPdf() async {
    if (_filteredHistory.isEmpty) {
      _toast('No voucher sales found for the selected filter.', error: true);
      return;
    }

    final logo = await loadBrandLogo();
    final pdf = pw.Document();
    final total = _filteredHistory.fold<double>(
      0,
      (sum, h) => sum + (double.tryParse('${h['final_amount'] ?? 0}') ?? 0),
    );
    final totalPending = _filteredHistory.fold<double>(
      0,
      (sum, h) => sum + (double.tryParse('${h['balance_amount'] ?? 0}') ?? 0),
    );

    final List<String> activeFilterList = [];
    if (_selectedHistoryDate != null) {
      activeFilterList.add(
        'Date: ${_selectedHistoryDate!.day.toString().padLeft(2, '0')}-${_selectedHistoryDate!.month.toString().padLeft(2, '0')}-${_selectedHistoryDate!.year}',
      );
    } else {
      activeFilterList.add('Date: All Dates');
    }
    if (_historyCandidateFilter.trim().isNotEmpty) {
      activeFilterList.add('Candidate: ${_historyCandidateFilter.trim()}');
    }
    if (_historySelectedExamType != null && _historySelectedExamType != 'All') {
      activeFilterList.add('Exam: $_historySelectedExamType');
    }
    final filterLabel = activeFilterList.join('  |  ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pdfReportHeader(
              logo: logo,
              title: 'Voucher Sales History Report',
              docDate: dateTime(DateTime.now().toIso8601String()),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    'Filters: $filterLabel',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfBrand.textDark,
                    ),
                  ),
                ),
                pw.Text(
                  'Total Records: ${_filteredHistory.length}',
                  style: const pw.TextStyle(fontSize: 11, color: PdfBrand.textMuted),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: pw.BoxDecoration(
                color: PdfBrand.tintStrong,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'Total Sales: Rs ${total.toStringAsFixed(2)}   |   Total Pending: Rs ${totalPending.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfBrand.primaryDark,
                ),
              ),
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: [
                'S.No',
                'Date',
                'Voucher',
                'Candidate',
                'Exam',
                'Mobile',
                'Amount (Rs)',
                'Pending (Rs)',
                'Payment',
                'Status',
              ],
              data: _filteredHistory.asMap().entries.map((entry) {
                final i = entry.key;
                final h = entry.value;
                return [
                  '${i + 1}',
                  dateTime(h['sold_at']).split(' ').first,
                  '${h['voucher_code'] ?? '-'}',
                  '${h['student_name'] ?? '-'}',
                  '${h['exam_type_name'] ?? '-'}',
                  '${h['mobile'] ?? h['student_mobile'] ?? '-'}',
                  (double.tryParse('${h['final_amount'] ?? 0}') ?? 0)
                      .toStringAsFixed(2),
                  (double.tryParse('${h['balance_amount'] ?? 0}') ?? 0)
                      .toStringAsFixed(2),
                  '${h['payment_mode'] ?? '-'}',
                  '${h['payment_status'] ?? '-'}',
                ];
              }).toList(),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(1.1),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(1.2),
                6: pw.FlexColumnWidth(1.0),
                7: pw.FlexColumnWidth(1.0),
                8: pw.FlexColumnWidth(0.9),
                9: pw.FlexColumnWidth(0.9),
              },
              headerStyle: pdfTableHeaderStyle(fontSize: 8),
              headerDecoration: pdfTableHeaderDecoration,
              headerAlignment: pw.Alignment.center,
              headerPadding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 5),
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 8, color: PdfBrand.textDark),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              oddRowDecoration: pdfTableOddRowDecoration,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'voucher_history_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<void> _exportHistoryExcel() async {
    if (_filteredHistory.isEmpty) {
      _toast('No voucher sales found for the selected filter.', error: true);
      return;
    }

    String csv(dynamic value) {
      final text = '${value ?? '-'}'.replaceAll('"', '""');
      return '"$text"';
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Voucher Code,Student Name,Mobile,Sold At,Amount,Paid Amount,Pending Amount,Payment Mode,Payment Status,Payment Reference',
    );

    for (final h in _filteredHistory) {
      buffer.writeln(
        [
          csv(h['voucher_code']),
          csv(h['student_name']),
          csv(h['mobile'] ?? h['student_mobile']),
          csv(dateTime(h['sold_at'])),
          (double.tryParse('${h['final_amount'] ?? 0}') ?? 0).toStringAsFixed(
            2,
          ),
          (double.tryParse('${h['paid_amount'] ?? 0}') ?? 0).toStringAsFixed(2),
          (double.tryParse('${h['balance_amount'] ?? 0}') ?? 0).toStringAsFixed(
            2,
          ),
          csv(h['payment_mode']),
          csv(h['payment_status']),
          csv(h['payment_reference']),
        ].join(','),
      );
    }

    final bytes = Uint8List.fromList(buffer.toString().codeUnits);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'voucher_history_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }
  Widget _historyFilterBar() {
    final selected = _selectedHistoryDate;
    final hasActiveFilter = selected != null ||
        _historyCandidateFilter.isNotEmpty ||
        (_historySelectedExamType != null && _historySelectedExamType != 'All');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasActiveFilter ? const Color(0xFFC4B5FD) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'History Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              if (hasActiveFilter)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      color: Color(0xFF6C1FB0),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // 1. Date filter (Existing)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _pickHistoryFilterDate,
              onLongPress: _clearHistoryFilterDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: selected != null
                      ? const Color(0xFFEDE9FE)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected != null
                        ? const Color(0xFFC4B5FD)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 19,
                      color: selected != null
                          ? const Color(0xFF6C1FB0)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selected == null
                            ? 'Filter by sale date'
                            : 'Date: ${_historyDateLabel(selected)} ${selected.year}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: selected != null
                              ? const Color(0xFF6C1FB0)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                    if (selected != null)
                      GestureDetector(
                        onTap: _clearHistoryFilterDate,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFF6C1FB0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 2. Candidate Name input
          TextField(
            controller: _historyCandidateCtrl,
            decoration: InputDecoration(
              hintText: 'Candidate name, mobile, or voucher...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.person_search_rounded, size: 20, color: Color(0xFF6C1FB0)),
              suffixIcon: _historyCandidateCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _historyCandidateCtrl.clear();
                        setState(() {
                          _historyCandidateFilter = '';
                          _applyHistoryFilter();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {});
            },
            onSubmitted: (val) {
              setState(() {
                _historyCandidateFilter = val.trim();
                _applyHistoryFilter();
              });
            },
          ),
          const SizedBox(height: 10),
          // 3. Exam Type Dropdown
          DropdownButtonFormField<String>(
            value: _historySelectedExamType,
            decoration: InputDecoration(
              hintText: 'Select Exam Type (All)',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              prefixIcon: const Icon(Icons.school_outlined, size: 20, color: Color(0xFF6C1FB0)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Exam Types', style: TextStyle(fontSize: 13)),
              ),
              ..._availableExamTypes.map(
                (et) => DropdownMenuItem<String>(
                  value: et,
                  child: Text(et, style: const TextStyle(fontSize: 13)),
                ),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _historySelectedExamType = val;
              });
            },
          ),
          const SizedBox(height: 12),
          // Action buttons: Apply Filter & Clear
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _historyCandidateFilter = _historyCandidateCtrl.text.trim();
                      _applyHistoryFilter();
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C1FB0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Apply Filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _clearHistoryFilters,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF64748B)),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _showHistoryExportOptions(context),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFC4B5FD)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.print_rounded,
                          size: 15,
                          color: Color(0xFF6C1FB0),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          hasActiveFilter
                              ? 'Export Filtered Report (${_filteredHistory.length})'
                              : 'Print / Export Report (${_filteredHistory.length})',
                          style: const TextStyle(
                            color: Color(0xFF6C1FB0),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _historyTab() {
    final hasActiveFilter = _selectedHistoryDate != null ||
        _historyCandidateFilter.isNotEmpty ||
        (_historySelectedExamType != null && _historySelectedExamType != 'All');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sales History',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              hasActiveFilter
                  ? '${_filteredHistory.length} of ${history.length}'
                  : '${_filteredHistory.length} records',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _historyFilterBar(),
        const SizedBox(height: 14),
        if (_filteredHistory.isEmpty)
          _empty(
            hasActiveFilter
                ? 'No voucher sales found matching your filter criteria.'
                : 'Every voucher sale will appear here with the complete student and payment details.',
          )
        else
          ..._filteredHistory.map(_historyTile),
      ],
    );
  }

  Widget _historyTile(Map<String, dynamic> h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showHistoryDetail(h),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${h['voucher_code'] ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (h['exam_type_name'] != null) ...[
                            const SizedBox(width: 6),
                            _examTag('${h['exam_type_name']}'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${h['student_name'] ?? '-'} • ${h['mobile'] ?? '-'}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateTime(h['sold_at']),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money(h['final_amount']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _statusChip('${h['payment_status'] ?? 'Pending'}'),
                    if ((double.tryParse('${h['balance_amount'] ?? 0}') ?? 0) >
                        0) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Pending ${money(h['balance_amount'])}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.orange,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _voucherTile(Map<String, dynamic> v, {bool allowSell = false}) {
    final sold = ['Sold', 'Assigned', 'Used'].contains(v['status']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: sold
            ? AppColors.green.withOpacity(.10)
            : CardTint.fill('${v['voucher_code'] ?? ''}'),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sold
              ? AppColors.green.withOpacity(.28)
              : CardTint.border('${v['voucher_code'] ?? ''}'),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showVoucherDetails(v),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                sold
                    ? Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: AppColors.green,
                        ),
                      )
                    : EntityAvatar(
                        seed: '${v['voucher_code'] ?? ''}',
                        icon: Icons.confirmation_num_outlined,
                        size: 42,
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${v['voucher_code'] ?? '-'}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (v['exam_type_name'] != null) ...[
                            const SizedBox(width: 6),
                            _examTag('${v['exam_type_name']}'),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sold
                            ? '${v['student_name'] ?? '-'} • ${v['student_mobile'] ?? '-'}'
                            : 'Available for sale',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sold
                            ? dateTime(v['sold_at'] ?? v['issued_at'])
                            : 'Purchase cost ${money(v['purchase_cost'])}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (allowSell)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: 'Sell this voucher',
                      onPressed: () => _showSellVoucher(preselected: v),
                      icon: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(v['sale_final_amount'] ?? v['selling_price']),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _statusChip('${v['status'] ?? '-'}'),
                      if ((double.tryParse(
                                '${v['sale_balance_amount'] ?? 0}',
                              ) ??
                              0) >
                          0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Pending ${money(v['sale_balance_amount'])}',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _examTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1D4ED8),
        ),
      ),
    );
  }

  Widget _statusChip(String text) {
    final good = ['Paid', 'Used', 'Sold'].contains(text);
    final color = good ? AppColors.green : AppColors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _empty(String message) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.receipt_long_outlined,
            size: 26,
            color: Colors.grey.shade400,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
        ),
      ],
    ),
  );

  // ================================================================
  // FORM HELPERS
  // ================================================================

  Widget _sectionTitle(String text) {
    final parts = text.split('. ');
    final num = parts.length > 1 ? parts[0] : '';
    final label = parts.length > 1 ? parts[1] : text;

    return Row(
      children: [
        Container(
          width: 22,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            num,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  Widget _input(
    TextEditingController c,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
    bool enabled = true,
  }) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      maxLines: maxLines,
      onChanged: onChanged,
      enabled: enabled,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6B7280)),
        filled: true,
        fillColor: const Color(0xFFF6F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF6F5FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      items: items
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text('$e', overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  // ================================================================
  // BULK PURCHASE DIALOG
  // ================================================================

  Future<void> _showPurchase() async {
    final globalBranchId = _branchContext.selectedBranchId;
    if (globalBranchId == null) {
      _toast(
        'Please select a branch from Dashboard before purchasing vouchers.',
        error: true,
      );
      return;
    }

    List<Map<String, dynamic>> examTypesList = [];
    try {
      final et = await api.examTypes();
      examTypesList = (et.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => '${e['status'] ?? 'Active'}' == 'Active')
          .toList();
    } catch (_) {}

    if (examTypesList.isEmpty) {
      _toast(
        'No exam types found. Please add an exam type first.',
        error: true,
      );
      return;
    }

    Map<String, dynamic>? selectedExam = examTypesList.first;
    final q = TextEditingController();
    final c = TextEditingController();
    final s = TextEditingController();
    final supplier = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * .92,
            ),
            padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: brandLinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.inventory_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bulk Purchase',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Add new voucher stock for a specific exam',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('1. Exam'),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selectedExam,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.school_outlined,
                        color: Color(0xFF6B7280),
                      ),
                      labelText: 'Exam Type *',
                      helperText: 'Which exam are these vouchers for?',
                      filled: true,
                      fillColor: const Color(0xFFF6F5FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.6,
                        ),
                      ),
                    ),
                    items: examTypesList
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              '${e['name']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedExam = v),
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('2. Batch & Pricing'),
                  const SizedBox(height: 9),
                  _input(
                    q,
                    'Quantity *',
                    Icons.numbers,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          c,
                          'Cost / Voucher *',
                          Icons.currency_rupee,
                          keyboard: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(
                          s,
                          'Selling Price / Voucher',
                          Icons.sell_outlined,
                          keyboard: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _input(
                    supplier,
                    'Supplier (optional)',
                    Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final qty = int.tryParse(q.text.trim()) ?? 0;
                              final cost = double.tryParse(c.text.trim()) ?? 0;
                              final sell = double.tryParse(s.text.trim()) ?? 0;
                              if (selectedExam == null) {
                                _toast('Please select an exam.', error: true);
                                return;
                              }
                              if (qty <= 0 || cost <= 0) {
                                _toast(
                                  'Enter a valid quantity and purchase cost.',
                                  error: true,
                                );
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                await api.purchaseVouchers({
                                  'quantity': qty,
                                  'branch_id': globalBranchId,
                                  'exam_type_id': selectedExam!['id'],
                                  'cost_per_voucher': cost,
                                  'selling_price': sell,
                                  'supplier': supplier.text.trim(),
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                _toast('Voucher stock added successfully.');
                                await load();
                              } catch (e) {
                                setSheetState(() => saving = false);
                                _toast('Purchase failed: $e', error: true);
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(saving ? 'Saving...' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showVoucherList(String title, List<Map<String, dynamic>> rows) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * .8,
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 14),
            ...rows.map((v) => _voucherTile(v, allowSell: true)),
          ],
        ),
      ),
    );
  }

  Future<void> _showVoucherDetails(Map<String, dynamic> v) async {
    try {
      final r = await api.voucherDetails(v['id']);
      final data = Map<String, dynamic>.from(r.data['data'] ?? {});
      if (!mounted) return;
      _showDetailSheet(data);
    } catch (e) {
      _toast('Unable to load voucher details: $e', error: true);
    }
  }

  void _showHistoryDetail(Map<String, dynamic> h) {
    _showDetailSheet({
      'voucher': h,
      'purchase': {},
      'history': [h],
    });
  }

  void _showDetailSheet(Map<String, dynamic> data) {
    final v = Map<String, dynamic>.from(data['voucher'] ?? {});
    final p = Map<String, dynamic>.from(data['purchase'] ?? {});
    final hs = (data['history'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .9,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: ListView(
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.confirmation_num_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v['voucher_code'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _statusChip('${v['status'] ?? 'Available'}'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _detailSection('Voucher Information', [
              _detail('Voucher ID', '${v['voucher_code'] ?? '-'}'),
              _detail('Exam', '${v['exam_type_name'] ?? '-'}'),
              _detail(
                'Batch',
                '${p['batch_number'] ?? v['batch_number'] ?? '-'}',
              ),
              _detail('Purchase Date', '${p['purchase_date'] ?? '-'}'),
              _detail('Purchase Cost', money(v['purchase_cost'])),
              _detail('Selling Price', money(v['selling_price'])),
            ]),
            if (hs.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailSection(
                'Sale & Payment',
                [
                  _detail('Sold At', dateTime(hs.first['sold_at'])),
                  _detail('Amount', money(hs.first['final_amount'])),
                  _detail('Discount', money(hs.first['discount'])),
                  _detail('Paid Amount', money(hs.first['paid_amount'])),
                  _detail('Pending Amount', money(hs.first['balance_amount'])),
                  _detail(
                    'Payment',
                    '${hs.first['payment_mode'] ?? '-'} • ${hs.first['payment_status'] ?? '-'}',
                  ),
                  _detail(
                    'Reference',
                    '${hs.first['payment_reference'] ?? '-'}',
                  ),
                ],
                trailing: TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showUpdatePaymentSheet(v, hs.first);
                  },
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Voucher History',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (hs.isEmpty)
              Text(
                'Purchased and waiting for sale.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...hs.map(
                (h) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F7FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Voucher Sold',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              '${h['student_name'] ?? '-'} • ${dateTime(h['sold_at'])}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        money(h['final_amount']),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // UPDATE PAYMENT SHEET (change Pending/Partial -> Paid, or record a
  // partial payment amount, on an already-sold voucher)
  // ================================================================

  Future<void> _showUpdatePaymentSheet(
    Map<String, dynamic> v,
    Map<String, dynamic> sale,
  ) async {
    final finalAmount = double.tryParse('${sale['final_amount'] ?? 0}') ?? 0;
    final paidAmount = TextEditingController(
      text: '${sale['paid_amount'] ?? 0}',
    );
    final reference = TextEditingController(
      text: '${sale['payment_reference'] ?? ''}',
    );
    final notes = TextEditingController(text: '${sale['notes'] ?? ''}');
    String paymentMode = '${sale['payment_mode'] ?? 'Cash'}';
    if (!['Cash', 'UPI', 'Card', 'Bank Transfer'].contains(paymentMode))
      paymentMode = 'Cash';
    String paymentStatus = '${sale['payment_status'] ?? 'Pending'}';
    if (!['Paid', 'Pending', 'Partial'].contains(paymentStatus))
      paymentStatus = 'Pending';
    bool saving = false;

    void syncPaidAmount() {
      if (paymentStatus == 'Paid') {
        paidAmount.text = finalAmount.toStringAsFixed(2);
      } else if (paymentStatus == 'Pending') {
        paidAmount.text = '0';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .9,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Update Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '${v['voucher_code'] ?? ''} • ${sale['student_name'] ?? ''}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _dropdownField<String>(
                        label: 'Payment Mode',
                        value: paymentMode,
                        items: const ['Cash', 'UPI', 'Card', 'Bank Transfer'],
                        onChanged: (val) =>
                            setSheetState(() => paymentMode = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dropdownField<String>(
                        label: 'Payment Status',
                        value: paymentStatus,
                        items: const ['Paid', 'Pending', 'Partial'],
                        onChanged: (val) => setSheetState(() {
                          paymentStatus = val!;
                          syncPaidAmount();
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _input(
                        paidAmount,
                        'Paid Amount',
                        Icons.payments_outlined,
                        keyboard: TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: paymentStatus == 'Partial',
                        onChanged: (_) => setSheetState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F5FA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pending Amount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            Text(
                              money(
                                (finalAmount -
                                        (double.tryParse(
                                              paidAmount.text.trim(),
                                            ) ??
                                            0))
                                    .clamp(0, double.infinity),
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color:
                                    (finalAmount -
                                            (double.tryParse(
                                                  paidAmount.text.trim(),
                                                ) ??
                                                0)) >
                                        0
                                    ? AppColors.orange
                                    : AppColors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _input(
                  reference,
                  'Payment Reference (optional)',
                  Icons.tag_outlined,
                ),
                const SizedBox(height: 10),
                _input(
                  notes,
                  'Notes (optional)',
                  Icons.short_text_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            final paid =
                                double.tryParse(paidAmount.text.trim()) ?? 0;
                            if (paid < 0 || paid > finalAmount) {
                              _toast(
                                'Paid amount must be between 0 and the final amount.',
                                error: true,
                              );
                              return;
                            }
                            if (paymentStatus == 'Partial' &&
                                (paid <= 0 || paid >= finalAmount)) {
                              _toast(
                                'Enter an amount paid that is less than the final amount for Partial.',
                                error: true,
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              await api.updateVoucherPayment(v['id'], {
                                'payment_status': paymentStatus,
                                'paid_amount': paymentStatus == 'Paid'
                                    ? finalAmount
                                    : (paymentStatus == 'Pending' ? 0 : paid),
                                'payment_mode': paymentMode,
                                'payment_reference': reference.text.trim(),
                                'notes': notes.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _toast('Payment updated.');
                              await load();
                            } catch (e) {
                              setSheetState(() => saving = false);
                              _toast('Update failed: $e', error: true);
                            }
                          },
                    icon: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(saving ? 'Saving...' : 'Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailSection(
    String title,
    List<Widget> children, {
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 7),
          ...children,
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SELL VOUCHER SHEET
  // ================================================================

  Future<void> _showSellVoucher({Map<String, dynamic>? preselected}) async {
    final available = vouchers
        .where((v) => v['status'] == 'Available')
        .toList();
    if (available.isEmpty) {
      _toast(
        'No available voucher stock. Please purchase vouchers first.',
        error: true,
      );
      return;
    }

    Map<String, dynamic>? selected = preselected ?? available.first;
    final name = TextEditingController();
    final mobile = TextEditingController();
    final email = TextEditingController();
    final address = TextEditingController();
    final idNumber = TextEditingController();
    final price = TextEditingController(
      text: '${selected['selling_price'] ?? 0}',
    );
    final discount = TextEditingController(text: '0');
    final paidAmount = TextEditingController();
    final reference = TextEditingController();
    final notes = TextEditingController();
    String paymentMode = 'Cash';
    String paymentStatus = 'Paid';

    double finalAmountOf() {
      final sell = double.tryParse(price.text.trim()) ?? 0;
      final disc = double.tryParse(discount.text.trim()) ?? 0;
      return (sell - disc).clamp(0, double.infinity);
    }

    // Keep the Paid Amount field in sync with the selected payment status:
    // Paid -> full final amount, Pending -> 0, Partial -> whatever the
    // operator types in (defaults to empty so they must enter it).
    void syncPaidAmount() {
      if (paymentStatus == 'Paid') {
        paidAmount.text = finalAmountOf().toStringAsFixed(2);
      } else if (paymentStatus == 'Pending') {
        paidAmount.text = '0';
      }
    }

    syncPaidAmount();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final bottom = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * .92,
            ),
            padding: EdgeInsets.fromLTRB(20, 10, 20, bottom + 20),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.sell_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sell',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Create a voucher sale with its own student record',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sectionTitle('1. Voucher'),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<Map<String, dynamic>>(
                    value: selected,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(
                        Icons.confirmation_num_outlined,
                        color: Color(0xFF6B7280),
                      ),
                      labelText: 'Voucher ID',
                      filled: true,
                      fillColor: const Color(0xFFF6F5FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                    items: available
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v['voucher_code']}  •  ${money(v['selling_price'])}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setSheetState(() {
                        selected = v;
                        price.text = '${v['selling_price'] ?? 0}';
                        syncPaidAmount();
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('2. Candidate Details'),
                  const SizedBox(height: 9),
                  _input(name, 'Full Name *', Icons.person_outline_rounded),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          mobile,
                          'Mobile Number',
                          Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(
                          idNumber,
                          'ID / ID Number',
                          Icons.badge_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _input(
                    email,
                    'Email Address',
                    Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 10),
                  _input(
                    address,
                    'Address',
                    Icons.location_on_outlined,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),
                  _sectionTitle('3. Sale & Payment'),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          price,
                          'Selling Price',
                          Icons.currency_rupee,
                          keyboard: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setSheetState(syncPaidAmount),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(
                          discount,
                          'Discount',
                          Icons.discount_outlined,
                          keyboard: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setSheetState(syncPaidAmount),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _dropdownField<String>(
                          label: 'Payment Mode',
                          value: paymentMode,
                          items: const ['Cash', 'UPI', 'Card', 'Bank Transfer'],
                          onChanged: (v) =>
                              setSheetState(() => paymentMode = v!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _dropdownField<String>(
                          label: 'Payment Status',
                          value: paymentStatus,
                          items: const ['Paid', 'Pending', 'Partial'],
                          onChanged: (v) => setSheetState(() {
                            paymentStatus = v!;
                            syncPaidAmount();
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _input(
                          paidAmount,
                          'Paid Amount',
                          Icons.payments_outlined,
                          keyboard: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          enabled: paymentStatus == 'Partial',
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F5FA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Pending Amount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                money(
                                  (finalAmountOf() -
                                          (double.tryParse(
                                                paidAmount.text.trim(),
                                              ) ??
                                              0))
                                      .clamp(0, double.infinity),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      (finalAmountOf() -
                                              (double.tryParse(
                                                    paidAmount.text.trim(),
                                                  ) ??
                                                  0)) >
                                          0
                                      ? AppColors.orange
                                      : AppColors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _input(
                    reference,
                    'Payment Reference (optional)',
                    Icons.tag_outlined,
                  ),
                  const SizedBox(height: 10),
                  _input(
                    notes,
                    'Notes (optional)',
                    Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final n = name.text.trim();
                              if (n.isEmpty || selected == null) {
                                _toast(
                                  'Voucher ID and student name are required.',
                                  error: true,
                                );
                                return;
                              }
                              final sell =
                                  double.tryParse(price.text.trim()) ?? 0;
                              final disc =
                                  double.tryParse(discount.text.trim()) ?? 0;
                              if (sell <= 0 || disc < 0 || disc > sell) {
                                _toast(
                                  'Enter a valid selling price and discount.',
                                  error: true,
                                );
                                return;
                              }
                              final finalAmt = sell - disc;
                              final paid =
                                  double.tryParse(paidAmount.text.trim()) ?? 0;
                              if (paid < 0 || paid > finalAmt) {
                                _toast(
                                  'Paid amount must be between 0 and the final amount.',
                                  error: true,
                                );
                                return;
                              }
                              if (paymentStatus == 'Partial' &&
                                  (paid <= 0 || paid >= finalAmt)) {
                                _toast(
                                  'Enter how much the candidate actually paid (less than the final amount) for a Partial sale.',
                                  error: true,
                                );
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                await api.sellVoucher({
                                  'voucher_id': selected!['id'],
                                  'student_name': n,
                                  'mobile': mobile.text.trim(),
                                  'email': email.text.trim(),
                                  'address': address.text.trim(),
                                  'id_number': idNumber.text.trim(),
                                  'selling_price': sell,
                                  'discount': disc,
                                  'paid_amount': paymentStatus == 'Paid'
                                      ? finalAmt
                                      : (paymentStatus == 'Pending' ? 0 : paid),
                                  'payment_status': paymentStatus,
                                  'payment_mode': paymentMode,
                                  'payment_reference': reference.text.trim(),
                                  'notes': notes.text.trim(),
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                _toast('Voucher sold successfully.');
                                await load();
                              } catch (e) {
                                setSheetState(() => saving = false);
                                _toast('Sale failed: $e', error: true);
                              }
                            },
                      icon: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline),
                      label: Text(saving ? 'Saving...' : 'Sell'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// KPI CARD
// ================================================================

class _VoucherKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final Color iconColor;

  const _VoucherKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 9, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tint.withOpacity(.38), Colors.white.withOpacity(.94)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(.14), width: 1),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(.08),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -25,
            bottom: -35,
            child: Container(
              width: 105,
              height: 105,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(.035),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(.07),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.remove_rounded, size: 9, color: iconColor),
                        const SizedBox(width: 2),
                        Text(
                          '0%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -.3,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: double.infinity,
                height: 17,
                child: CustomPaint(
                  painter: _VoucherSparklinePainter(color: iconColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VoucherSparklinePainter extends CustomPainter {
  final Color color;

  const _VoucherSparklinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      Offset(0, size.height * .78),
      Offset(size.width * .14, size.height * .55),
      Offset(size.width * .28, size.height * .68),
      Offset(size.width * .42, size.height * .35),
      Offset(size.width * .56, size.height * .52),
      Offset(size.width * .70, size.height * .25),
      Offset(size.width * .84, size.height * .36),
      Offset(size.width, size.height * .10),
    ];

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(path, paint);

    canvas.drawCircle(points.last, 2.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _VoucherSparklinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

// ================================================================
// QUICK ACTION CARD
// ================================================================

class _VoucherQuickAction extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _VoucherQuickAction({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first.withOpacity(.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SECTION CARD
// ================================================================

class _VoucherSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _VoucherSectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}