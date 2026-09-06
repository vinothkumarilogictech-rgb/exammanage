import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../providers/branch_context.dart';
import 'package:provider/provider.dart';

class VoucherPurchaseInvoicesTab extends StatefulWidget {
  const VoucherPurchaseInvoicesTab({super.key});

  @override
  State<VoucherPurchaseInvoicesTab> createState() => _VoucherPurchaseInvoicesTabState();
}

class _VoucherPurchaseInvoicesTabState extends State<VoucherPurchaseInvoicesTab> {
  final api = DioClient();
  late final BranchContext _branchContext;
  List<VoucherPurchaseInvoice> _invoices = [];
  List<ExamTypeItem> _examTypes = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'All';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    _load();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onBranchChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      await _branchContext.ensureLoaded();
      final branchId = _branchContext.selectedBranchId;
      final results = await Future.wait([
        api.invoices(branchId: branchId, status: _statusFilter),
        api.examTypes(),
      ]);
      final invoiceData = results[0].data['data'] as List? ?? const [];
      final examData = results[1].data['data'] as List? ?? const [];
      _invoices = invoiceData
          .map((e) => VoucherPurchaseInvoice.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      _examTypes = examData
          .map((e) => ExamTypeItem.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.status.toLowerCase() == 'active')
          .toList();
    } catch (e) {
      _error = 'Failed to load invoices: $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<VoucherPurchaseInvoice> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _invoices.where((i) {
      if (q.isEmpty) return true;
      return i.invoiceNumber.toLowerCase().contains(q) || i.supplier.toLowerCase().contains(q) ||
          i.items.any((x) => x.examName.toLowerCase().contains(q));
    }).toList();
  }

  double get _total => _invoices.where((x) => x.status == 'Active').fold(0, (s, x) => s + x.totalAmount);
  double get _paid => _invoices.where((x) => x.status == 'Active').fold(0, (s, x) => s + x.paidAmount);
  double get _balance => _invoices.where((x) => x.status == 'Active').fold(0, (s, x) => s + x.balanceAmount);

  String _money(double v) => '₹${v.toStringAsFixed(2)}';

  // PDF default fonts may not contain the Rupee (₹) or bullet (•) glyphs.
  // Use ASCII-safe currency/separators in printed invoices to avoid square boxes.
  String _pdfMoney(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  String _date(String value) {
    final d = DateTime.tryParse(value);
    if (d == null) return value.isEmpty ? '-' : value;
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.red : AppColors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.symmetric(vertical: 70), child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_error != null) {
      return Column(children: [
        const SizedBox(height: 30),
        const Icon(Icons.receipt_long_outlined, size: 44, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry')),
      ]);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Invoices', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('Manage bulk CELPIP and TOEFL voucher purchase invoices.', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
        ])),
        _smallAction(Icons.add_rounded, 'Add', _showAddInvoice),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _stat('Invoices', '${_invoices.length}', Icons.receipt_long_rounded, const Color(0xFFEDE9FE), AppColors.primary)),
        const SizedBox(width: 8),
        Expanded(child: _stat('Paid', _money(_paid), Icons.payments_rounded, const Color(0xFFDCFCE7), AppColors.green)),
        const SizedBox(width: 8),
        Expanded(child: _stat('Balance', _money(_balance), Icons.account_balance_wallet_rounded, const Color(0xFFFEF3C7), AppColors.orange)),
      ]),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search invoice, supplier or exam',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true, fillColor: AppColors.searchFill,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
          )),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            initialValue: _statusFilter,
            onSelected: (v) { setState(() => _statusFilter = v); _load(); },
            itemBuilder: (_) => const [PopupMenuItem(value: 'All', child: Text('All')), PopupMenuItem(value: 'Active', child: Text('Active')), PopupMenuItem(value: 'Cancelled', child: Text('Cancelled'))],
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.filter_list_rounded, size: 18), const SizedBox(width: 5), Text(_statusFilter, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))])),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      if (_filtered.isEmpty)
        _emptyInvoices()
      else
        ..._filtered.map(_invoiceCard),
    ]);
  }

  Widget _smallAction(IconData icon, String text, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)), child: Row(children: [Icon(icon, color: Colors.white, size: 17), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5))])),
  );

  Widget _stat(String title, String value, IconData icon, Color bg, Color fg) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Row(children: [Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 17, color: fg)), const SizedBox(width: 7), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis)]))]),
  );

  Widget _emptyInvoices() => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 20),
    decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5E7EB))),
    child: Column(children: [Container(width: 58, height: 58, decoration: BoxDecoration(color: const Color(0xFFF0E3FA), borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 29)), const SizedBox(height: 12), const Text('No invoices found', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 5), Text('Create an invoice for a bulk exam-voucher purchase.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5), textAlign: TextAlign.center), const SizedBox(height: 14), _smallAction(Icons.add_rounded, 'Create Invoice', _showAddInvoice)]),
  );

  Widget _invoiceCard(VoucherPurchaseInvoice invoice) {
    final itemText = invoice.items.map((x) => '${x.examName} × ${x.quantity}').join('  •  ');
    final statusColor = invoice.status == 'Cancelled' ? AppColors.red : (invoice.paymentStatus == 'Paid' ? AppColors.green : AppColors.orange);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE7E5E4)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 43, height: 43, decoration: BoxDecoration(color: const Color(0xFFF0E3FA), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(invoice.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5)),
            const SizedBox(height: 3),
            Text(invoice.supplier, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text('${_date(invoice.invoiceDate)}  •  ${invoice.branchName}', style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(_money(invoice.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)), const SizedBox(height: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(.10), borderRadius: BorderRadius.circular(20)), child: Text(invoice.status == 'Cancelled' ? 'Cancelled' : invoice.paymentStatus, style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 10.5)))]),
        ]),
        const SizedBox(height: 11),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(11)), child: Text(itemText.isEmpty ? 'No items' : itemText, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)))),
        const SizedBox(height: 9),
        Row(children: [
          Text('Paid ${_money(invoice.paidAmount)}', style: TextStyle(fontSize: 10.8, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Text('Balance ${_money(invoice.balanceAmount)}', style: TextStyle(fontSize: 10.8, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          const Spacer(),
          _cardAction(Icons.visibility_outlined, 'View', () => _showView(invoice)),
          if (invoice.status == 'Active') ...[
            const SizedBox(width: 4),
            _cardAction(Icons.edit_outlined, 'Edit', () => _showEdit(invoice)),
            const SizedBox(width: 4),
            _cardAction(Icons.print_outlined, 'Print', () => _printInvoice(invoice)),
          ],
        ]),
      ]),
    );
  }

  Widget _cardAction(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5), child: Row(children: [Icon(icon, size: 15, color: AppColors.primary), const SizedBox(width: 3), Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.primary))])));

  Future<void> _showAddInvoice() => _showInvoiceForm();
  Future<void> _showEdit(VoucherPurchaseInvoice invoice) => _showInvoiceForm(existing: invoice);

  Future<void> _showInvoiceForm({VoucherPurchaseInvoice? existing}) async {
    final branchId = _branchContext.selectedBranchId;
    if (branchId == null) { _toast('Please select a branch from Dashboard first.', error: true); return; }
    if (_examTypes.isEmpty) { _toast('Please add an active exam type first.', error: true); return; }

    final invoiceNo = TextEditingController(text: existing?.invoiceNumber ?? '');
    final supplier = TextEditingController(text: existing?.supplier ?? '');
    final reference = TextEditingController(text: existing?.paymentReference ?? '');
    final paid = TextEditingController(text: existing == null ? '' : existing.paidAmount.toStringAsFixed(2));
    final notes = TextEditingController(text: existing?.notes ?? '');
    DateTime invoiceDate = DateTime.tryParse(existing?.invoiceDate ?? '') ?? DateTime.now();
    String paymentStatus = existing?.paymentStatus ?? 'Pending';
    String paymentMode = existing?.paymentMode.isNotEmpty == true ? existing!.paymentMode : 'Bank Transfer';
    final rows = <_InvoiceDraftLine>[];
    if (existing != null) {
      for (final item in existing.items) {
        final exam = _examTypes.where((x) => x.id == item.examTypeId).firstOrNull ?? _examTypes.first;
        rows.add(_InvoiceDraftLine(exam: exam, quantity: item.quantity, unitPrice: item.unitPrice, discount: item.discount, tax: item.tax));
      }
    } else {
      rows.add(_InvoiceDraftLine(exam: _examTypes.first));
    }
    bool saving = false;

    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(builder: (sheetCtx, setSheet) {
        double subtotal() => rows.fold(0, (s, r) => s + r.quantity * r.unitPrice);
        double discount() => rows.fold(0, (s, r) => s + r.discount);
        double tax() => rows.fold(0, (s, r) => s + r.tax);
        double total() => subtotal() - discount() + tax();
        final totalValue = total();
        final paidValue = double.tryParse(paid.text) ?? 0;
        final balanceValue = (totalValue - paidValue).clamp(0, double.infinity).toDouble();
        final media = MediaQuery.of(sheetCtx);
        final availableHeight = media.size.height - media.viewInsets.bottom - media.padding.top - media.padding.bottom;
        return SafeArea(
          top: false,
          child: Container(
          constraints: BoxConstraints(maxHeight: availableHeight * .97),
          padding: EdgeInsets.fromLTRB(18, 10, 18, media.viewInsets.bottom + 12),
          decoration: const BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)))),
            const SizedBox(height: 14),
            Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF0E3FA), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(existing == null ? 'Add' : 'Edit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text('Bulk exam voucher purchase invoice', style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600))]))]),
            const SizedBox(height: 18),
            _formLabel('Invoice Details'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(invoiceNo, 'Invoice No. (optional)', Icons.tag_rounded)),
              const SizedBox(width: 9),
              Expanded(child: InkWell(onTap: () async { final d = await showDatePicker(context: sheetCtx, firstDate: DateTime(2020), lastDate: DateTime(2100), initialDate: invoiceDate); if (d != null) setSheet(() => invoiceDate = d); }, child: _displayField('Date', '${invoiceDate.day.toString().padLeft(2,'0')}-${invoiceDate.month.toString().padLeft(2,'0')}-${invoiceDate.year}', Icons.calendar_today_rounded))),
            ]),
            const SizedBox(height: 9),
            _field(supplier, 'Supplier *', Icons.storefront_outlined),
            const SizedBox(height: 16),
            Row(children: [const Expanded(child: Text('Invoice Items', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))), TextButton.icon(onPressed: () => setSheet(() => rows.add(_InvoiceDraftLine(exam: _examTypes.first))), icon: const Icon(Icons.add, size: 17), label: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w800)))]),
            const SizedBox(height: 5),
            ...rows.asMap().entries.map((entry) {
              final index = entry.key; final row = entry.value;
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFE2E8F0))), child: Column(children: [
                Row(children: [Expanded(child: DropdownButtonFormField<ExamTypeItem>(value: row.exam, isExpanded: true, decoration: _decoration('Exam *', Icons.school_outlined), items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) setSheet(() => row.exam = v); })), if (rows.length > 1) IconButton(onPressed: () => setSheet(() => rows.removeAt(index)), icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red))]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: _numberField(row.qtyCtrl, 'Quantity', Icons.numbers_rounded, integer: true, onChanged: () => setSheet(() {}))), const SizedBox(width: 7), Expanded(child: _numberField(row.priceCtrl, 'Unit Price', Icons.currency_rupee_rounded, onChanged: () => setSheet(() {})))]),
                const SizedBox(height: 7),
                Row(children: [Expanded(child: _numberField(row.discountCtrl, 'Discount', Icons.discount_outlined, onChanged: () => setSheet(() {}))), const SizedBox(width: 7), Expanded(child: _numberField(row.taxCtrl, 'Tax', Icons.percent_rounded, onChanged: () => setSheet(() {})))]),
                const SizedBox(height: 7),
                Align(alignment: Alignment.centerRight, child: Text('Line Total: ${_money(row.total)}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 12))),
              ]));
            }),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFF7F5FD), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEDE9FE))), child: Column(children: [
              _summaryRow('Subtotal', subtotal()), _summaryRow('Discount', -discount()), _summaryRow('Tax', tax()), const Divider(height: 18), _summaryRow('Grand Total', totalValue, bold: true),
            ])),
            const SizedBox(height: 16),
            _formLabel('Payment Details'), const SizedBox(height: 8),
            Row(children: [Expanded(child: DropdownButtonFormField<String>(value: paymentStatus, isExpanded: true, decoration: _decoration('Payment Status', Icons.payments_outlined), items: const ['Pending','Partial','Paid'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setSheet(() => paymentStatus = v ?? 'Pending'))), const SizedBox(width: 8), Expanded(child: DropdownButtonFormField<String>(value: paymentMode, isExpanded: true, decoration: _decoration('Payment Mode', Icons.account_balance_rounded), items: const ['Cash','UPI','Card','Bank Transfer','Cheque','Other'].map((x) => DropdownMenuItem(value: x, child: Text(x, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setSheet(() => paymentMode = v ?? 'Bank Transfer')))]),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: _numberField(paid, 'Paid Amount', Icons.currency_rupee_rounded, onChanged: () => setSheet(() {}))), const SizedBox(width: 8), Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFEDE9FE))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Balance', style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(_money(balanceValue), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14))])))]),
            const SizedBox(height: 8),
            _field(reference, 'Payment Reference (optional)', Icons.confirmation_number_outlined), const SizedBox(height: 8), _field(notes, 'Notes (optional)', Icons.notes_rounded, maxLines: 2),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), onPressed: saving ? null : () async {
              final payloadItems = <Map<String, dynamic>>[];
              for (final row in rows) { final qty = row.quantity; final price = row.unitPrice; if (qty <= 0 || price < 0) { _toast('Enter valid quantity and unit price for every item.', error: true); return; } payloadItems.add({'exam_type_id': row.exam.id, 'quantity': qty, 'unit_price': price, 'discount': row.discount, 'tax': row.tax}); }
              if (supplier.text.trim().isEmpty) { _toast('Supplier is required.', error: true); return; }
              final p = double.tryParse(paid.text) ?? 0; if (p < 0 || p > totalValue) { _toast('Paid amount cannot exceed the grand total.', error: true); return; }
              setSheet(() => saving = true);
              try {
                final data = {'invoice_number': invoiceNo.text.trim(), 'supplier': supplier.text.trim(), 'invoice_date': '${invoiceDate.year.toString().padLeft(4,'0')}-${invoiceDate.month.toString().padLeft(2,'0')}-${invoiceDate.day.toString().padLeft(2,'0')}', 'branch_id': branchId, 'payment_status': paymentStatus, 'payment_mode': paymentMode, 'payment_reference': reference.text.trim(), 'paid_amount': p, 'notes': notes.text.trim(), 'items': payloadItems};
                if (existing == null) { await api.createInvoice(data); } else { await api.updateInvoice(existing.id, data); }
                if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                _toast(existing == null ? 'Invoice created successfully.' : 'Invoice updated successfully.');
                await _load();
              } catch (e) { setSheet(() => saving = false); _toast('Invoice save failed: $e', error: true); }
            }, icon: saving ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_circle_outline), label: Text(saving ? 'Saving...' : (existing == null ? 'Save' : 'Update'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)))),
          ])),
        ));
      }),
    );
    invoiceNo.dispose(); supplier.dispose(); reference.dispose(); paid.dispose(); notes.dispose();
    for (final row in rows) row.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13), border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: Color(0xFFE2E8F0))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.primary, width: 1.4)));
  Widget _field(TextEditingController c, String hint, IconData icon, {int maxLines = 1}) => TextField(controller: c, maxLines: maxLines, decoration: _decoration(hint, icon));
  Widget _numberField(TextEditingController c, String hint, IconData icon, {bool integer = false, VoidCallback? onChanged}) => TextField(controller: c, keyboardType: TextInputType.numberWithOptions(decimal: !integer), onChanged: (_) => onChanged?.call(), decoration: _decoration(hint, icon));
  Widget _displayField(String label, String value, IconData icon) => InputDecorator(decoration: _decoration(label, icon), child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)));
  Widget _formLabel(String text) => Text(text, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14));
  Widget _summaryRow(String label, double value, {bool bold = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600))), Text(_money(value), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, fontSize: bold ? 15 : 12.5, color: bold ? AppColors.primary : const Color(0xFF334155)))]));

  void _showView(VoucherPurchaseInvoice invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(5)))),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFF0E3FA), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(invoice.invoiceNumber, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)), Text(invoice.supplier, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5))])),
                    Text(_money(invoice.totalAmount), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 16),
                _detail('Invoice Date', _date(invoice.invoiceDate)),
                _detail('Branch', invoice.branchName),
                _detail('Payment Status', invoice.paymentStatus),
                _detail('Payment Mode', invoice.paymentMode.isEmpty ? '-' : invoice.paymentMode),
                if (invoice.paymentReference.isNotEmpty) _detail('Payment Reference', invoice.paymentReference),
                const SizedBox(height: 10),
                const Text('Items', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                ...invoice.items.map((x) => Container(
                  margin: const EdgeInsets.only(bottom: 7),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.examName, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${x.quantity} × ${_money(x.unitPrice)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))])),
                    Text(_money(x.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                )),
                const Divider(height: 20),
                _summaryRow('Subtotal', invoice.subtotal),
                _summaryRow('Discount', -invoice.discount),
                _summaryRow('Tax', invoice.tax),
                _summaryRow('Grand Total', invoice.totalAmount, bold: true),
                _summaryRow('Paid', invoice.paidAmount),
                _summaryRow('Balance', invoice.balanceAmount),
                if (invoice.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Notes', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.grey.shade700)),
                  const SizedBox(height: 3),
                  Text(invoice.notes, style: TextStyle(color: Colors.grey.shade700)),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _printInvoice(invoice); }, icon: const Icon(Icons.print_outlined), label: const Text('Print / PDF'))),
                    if (invoice.status == 'Active') ...[
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton.icon(onPressed: () { Navigator.pop(context); _confirmCancel(invoice); }, icon: const Icon(Icons.cancel_outlined, color: AppColors.red), label: const Text('Cancel'))),
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

  Widget _detail(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 125, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12))), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)))]));

  Future<void> _confirmCancel(VoucherPurchaseInvoice invoice) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Cancel Invoice?'), content: Text('Invoice ${invoice.invoiceNumber} will be marked as Cancelled. It will not be deleted.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel Invoice'))]));
    if (ok != true) return;
    try { await api.deleteInvoice(invoice.id); _toast('Invoice cancelled.'); await _load(); } catch (e) { _toast('Unable to cancel invoice: $e', error: true); }
  }

  Future<void> _printInvoice(VoucherPurchaseInvoice invoice) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(34), build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('EXAM MANAGEMENT', style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 3), pw.Text('Voucher Purchase Invoice', style: const pw.TextStyle(fontSize: 11))]), pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text(invoice.invoiceNumber, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)), pw.Text(_date(invoice.invoiceDate), style: const pw.TextStyle(fontSize: 10))])]), pw.SizedBox(height: 20), pw.Container(padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(7)), child: pw.Row(children: [pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Supplier', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.SizedBox(height: 3), pw.Text(invoice.supplier, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))])), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Branch', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)), pw.SizedBox(height: 3), pw.Text(invoice.branchName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))]))])), pw.SizedBox(height: 18), pw.Table.fromTextArray(headers: const ['S.No', 'Exam', 'Qty', 'Unit Price', 'Discount', 'Tax', 'Amount'], data: [for (var i = 0; i < invoice.items.length; i++) [ '${i+1}', invoice.items[i].examName, '${invoice.items[i].quantity}', _pdfMoney(invoice.items[i].unitPrice), _pdfMoney(invoice.items[i].discount), _pdfMoney(invoice.items[i].tax), _pdfMoney(invoice.items[i].totalAmount) ]]), pw.SizedBox(height: 14), pw.Align(alignment: pw.Alignment.centerRight, child: pw.SizedBox(width: 220, child: pw.Column(children: [_pdfLine('Subtotal', invoice.subtotal), _pdfLine('Discount', invoice.discount), _pdfLine('Tax', invoice.tax), pw.Divider(), _pdfLine('Grand Total', invoice.totalAmount, bold: true), _pdfLine('Paid', invoice.paidAmount), _pdfLine('Balance', invoice.balanceAmount)]))), pw.SizedBox(height: 20), pw.Text('Payment: ${invoice.paymentStatus}  |  ${invoice.paymentMode.isEmpty ? '-' : invoice.paymentMode}', style: const pw.TextStyle(fontSize: 10)), if (invoice.paymentReference.isNotEmpty) pw.Text('Reference: ${invoice.paymentReference}', style: const pw.TextStyle(fontSize: 10)), if (invoice.notes.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 8), child: pw.Text('Notes: ${invoice.notes}', style: const pw.TextStyle(fontSize: 10))), pw.Spacer(), pw.Divider(), pw.Text('This invoice records the financial purchase of exam vouchers. Voucher codes and usage are managed separately in Voucher Management.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ])));
    await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: invoice.invoiceNumber);
  }

  pw.Widget _pdfLine(String label, double value, {bool bold = false}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 2), child: pw.Row(children: [pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))), pw.Text(_pdfMoney(value), style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))]));
}

class _InvoiceDraftLine {
  ExamTypeItem exam;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discountCtrl;
  final TextEditingController taxCtrl;

  _InvoiceDraftLine({required this.exam, int quantity = 1, double unitPrice = 0, double discount = 0, double tax = 0})
      : qtyCtrl = TextEditingController(text: '$quantity'),
        priceCtrl = TextEditingController(text: unitPrice == 0 ? '' : unitPrice.toStringAsFixed(2)),
        discountCtrl = TextEditingController(text: discount == 0 ? '' : discount.toStringAsFixed(2)),
        taxCtrl = TextEditingController(text: tax == 0 ? '' : tax.toStringAsFixed(2));

  int get quantity => int.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get discount => double.tryParse(discountCtrl.text.trim()) ?? 0;
  double get tax => double.tryParse(taxCtrl.text.trim()) ?? 0;
  double get total => quantity * unitPrice - discount + tax;

  void dispose() { qtyCtrl.dispose(); priceCtrl.dispose(); discountCtrl.dispose(); taxCtrl.dispose(); }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
