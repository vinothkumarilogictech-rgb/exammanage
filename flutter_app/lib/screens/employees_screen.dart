import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override State<EmployeesScreen> createState() => EmployeesScreenState();
}

class EmployeesScreenState extends State<EmployeesScreen> {
  final api = DioClient();
  late final BranchContext branchContext;
  List<Employee> employees = [];
  bool loading = true;

  @override
  void initState() { super.initState(); branchContext = context.read<BranchContext>(); branchContext.addListener(_branchChanged); load(); }
  @override
  void dispose() { branchContext.removeListener(_branchChanged); super.dispose(); }
  void _branchChanged() { if (mounted) load(); }

  Future<void> load() async {
    await branchContext.ensureLoaded();
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final r = await api.employees(branchId: branchContext.selectedBranchId);
      final rows = (r.data['data'] as List? ?? const [])
          .map((x) => Employee.fromMap(Map<String, dynamic>.from(x))).toList();
      if (mounted) setState(() => employees = rows);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Widget field(TextEditingController c, String label, {bool enabled = true, bool number = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, enabled: enabled,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
  );

  Future<void> editEmployee([Employee? e]) async {
    final bid = branchContext.selectedBranchId;
    if (bid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a branch from Dashboard first.'))); return; }
    final code = TextEditingController(text: e?.employeeId ?? ''), name = TextEditingController(text: e?.fullName ?? ''), des = TextEditingController(text: e?.designation ?? ''), phone = TextEditingController(text: e?.phone ?? ''), email = TextEditingController(text: e?.email ?? ''), address = TextEditingController(text: e?.address ?? ''), salary = TextEditingController(text: e == null ? '' : e.basicSalary.toString());
    DateTime joining = e == null ? DateTime.now() : (DateTime.tryParse(e.joiningDate) ?? DateTime.now());
    String status = e?.status ?? 'Active';
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e == null ? 'Add Employee' : 'Edit Employee', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16), field(code, 'Employee Code *', enabled: e == null), field(name, 'Full Name *'), field(des, 'Designation *'), field(phone, 'Phone'), field(email, 'Email'), field(address, 'Address'), field(salary, 'Basic Salary', number: true),
        Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.lock_outline, size: 18), const SizedBox(width: 8), Text(branchContext.selectedBranchName ?? 'Selected branch', style: const TextStyle(fontWeight: FontWeight.w700))])),
        const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today), title: Text('Joining: ${joining.year}-${joining.month.toString().padLeft(2,'0')}-${joining.day.toString().padLeft(2,'0')}'), onTap: () async { final d = await showDatePicker(context: ctx, initialDate: joining, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setSheet(() => joining = d); }),
        if (e != null) DropdownButtonFormField<String>(value: status, items: const [DropdownMenuItem(value: 'Active', child: Text('Active')), DropdownMenuItem(value: 'Inactive', child: Text('Inactive'))], onChanged: (v) { if (v != null) setSheet(() => status = v); }, decoration: const InputDecoration(labelText: 'Status')),
        const SizedBox(height: 16), SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () async {
          if (code.text.trim().isEmpty || name.text.trim().isEmpty || des.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Code, name and designation are required.'))); return; }
          final data = {'employee_id': code.text.trim(), 'full_name': name.text.trim(), 'designation': des.text.trim(), 'contact_number': phone.text.trim(), 'email': email.text.trim(), 'address': address.text.trim(), 'basic_salary': double.tryParse(salary.text.trim()) ?? 0, 'joining_date': '${joining.year}-${joining.month.toString().padLeft(2,'0')}-${joining.day.toString().padLeft(2,'0')}', 'status': status, 'branch_id': bid};
          try { if (e == null) { await api.createEmployee(data); } else { data.remove('branch_id'); await api.updateEmployee(e.id, data); } if (ctx.mounted) Navigator.pop(ctx); await load(); }
          catch (err) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $err'))); }
        }, child: Text(e == null ? 'Save Employee' : 'Update Employee'))),
      ])),
    )));
    for (final c in [code,name,des,phone,email,address,salary]) { c.dispose(); }
  }

  Future<void> salaryHistory(Employee e) async {
    try {
      final r = await api.employeeSalaryHistory(e.id, branchId: branchContext.selectedBranchId);
      final rows = (r.data['data'] as List? ?? const []);
      if (!mounted) return;
      showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.fullName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), Text('${e.employeeId} • ${e.designation}'), const Divider(), const Text('Salary History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No salary payments yet.'))) else ...rows.map((x) => ListTile(leading: const Icon(Icons.payments_outlined), title: Text('₹ ${x['amount']}'), subtitle: Text('${x['date_incurred'] ?? ''} • ${x['payment_mode'] ?? ''}'))),
      ]))));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Employees')),
    floatingActionButton: FloatingActionButton(onPressed: () => editEmployee(), child: const Icon(Icons.add)),
    body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
      onRefresh: load,
      child: employees.isEmpty ? ListView(children: [const SizedBox(height: 250), Center(child: Text('No employees in selected branch'))]) : ListView.builder(
        padding: const EdgeInsets.all(14), itemCount: employees.length,
        itemBuilder: (_, i) { final e = employees[i]; return Card(child: ListTile(
          onTap: () => salaryHistory(e), leading: CircleAvatar(child: Text(e.fullName.isEmpty ? '?' : e.fullName[0].toUpperCase())),
          title: Text(e.fullName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${e.employeeId} • ${e.designation}\n${e.phone}'), isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await editEmployee(e); if (v == 'delete') { final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Deactivate employee?'), content: const Text('Financial history will be preserved.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))])); if (ok == true) { await api.deleteEmployee(e.id); await load(); } } }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete / Deactivate'))]),
        )); },
      ),
    ),
  );
}
