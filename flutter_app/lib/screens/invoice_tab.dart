import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';

/// Voucher purchase invoices tab, embedded inside [ExpensesScreen]'s
/// scroll view (its own list is non-scrollable — the parent screen
/// provides the scrolling).
class VoucherPurchaseInvoicesTab extends StatefulWidget {
  const VoucherPurchaseInvoicesTab({super.key});

  @override
  State<VoucherPurchaseInvoicesTab> createState() => _VoucherPurchaseInvoicesTabState();
}

class _VoucherPurchaseInvoicesTabState extends State<VoucherPurchaseInvoicesTab> {
  final api = DioClient();
  bool loading = true;
  String? error;
  List<VoucherPurchaseInvoice> invoices = [];
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
      final response = await api.voucherPurchaseInvoices(branchId: branchId);
      invoices = (response.data['data'] as List? ?? [])
          .map((e) => VoucherPurchaseInvoice.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      error = 'Failed to load purchase invoices: $e';
    }
    if (mounted) setState(() => loading = false);
  }

  String money(double value) => '₹${value.toStringAsFixed(2)}';

  String dateOnly(String value) {
    if (value.isEmpty) return '-';
    final d = DateTime.tryParse(value)?.toLocal();
    if (d == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.green;
      case 'partial':
        return AppColors.orange;
      case 'overdue':
      case 'cancelled':
        return AppColors.red;
      default:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: LoadingView(),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: ErrorView(message: error!, onRetry: load),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Purchase Invoices',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        const SizedBox(height: 8),
        if (invoices.isEmpty)
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
                  decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
                  child: Icon(Icons.request_quote_outlined, size: 26, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 14),
                Text('No voucher purchase invoices found.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
              ],
            ),
          )
        else
          ...invoices.map(_invoiceCard),
      ],
    );
  }

  Widget _invoiceCard(VoucherPurchaseInvoice inv) {
    final statusColor = _statusColor(inv.paymentStatus);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
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
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.request_quote_rounded, color: AppColors.primary, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.invoiceNumber.isEmpty ? 'Invoice #${inv.id}' : inv.invoiceNumber,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(
                      inv.supplier.isEmpty ? dateOnly(inv.invoiceDate) : '${inv.supplier} • ${dateOnly(inv.invoiceDate)}',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
                child: Text(inv.paymentStatus,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          if (inv.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            ...inv.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${item.examName} × ${item.quantity}',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                      ),
                      Text(money(item.totalAmount),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5)),
              Text(money(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
          if (inv.balanceAmount > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Balance', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                Text(money(inv.balanceAmount),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.red)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
