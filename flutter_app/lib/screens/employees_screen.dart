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
    final name = TextEditingController(text: e?.fullName ?? ''), des = TextEditingController(text: e?.designation ?? ''), phone = TextEditingController(text: e?.phone ?? ''), email = TextEditingController(text: e?.email ?? ''), address = TextEditingController(text: e?.address ?? ''), username = TextEditingController(), password = TextEditingController();
    DateTime joining = e == null ? DateTime.now() : (DateTime.tryParse(e.joiningDate) ?? DateTime.now());
    String status = e?.status ?? 'Active';
    await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e == null ? 'Add Employee' : 'Edit Employee', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16), field(name, 'Full Name *'), field(des, 'Designation *'), field(phone, 'Phone'), field(email, 'Email'), field(address, 'Address'), field(username, e == null ? 'Username *' : 'Username (optional)'), field(password, e == null ? 'Password *' : 'Password (optional)'),
        Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.lock_outline, size: 18), const SizedBox(width: 8), Text(branchContext.selectedBranchName ?? 'Selected branch', style: const TextStyle(fontWeight: FontWeight.w700))])),
        const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.calendar_today), title: Text('Joining: ${joining.year}-${joining.month.toString().padLeft(2,'0')}-${joining.day.toString().padLeft(2,'0')}'), onTap: () async { final d = await showDatePicker(context: ctx, initialDate: joining, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (d != null) setSheet(() => joining = d); }),
        if (e != null) DropdownButtonFormField<String>(value: status, items: const [DropdownMenuItem(value: 'Active', child: Text('Active')), DropdownMenuItem(value: 'Inactive', child: Text('Inactive'))], onChanged: (v) { if (v != null) setSheet(() => status = v); }, decoration: const InputDecoration(labelText: 'Status')),
        const SizedBox(height: 16), SizedBox(width: double.infinity, height: 50, child: FilledButton(onPressed: () async {
          if (name.text.trim().isEmpty || des.text.trim().isEmpty || (e == null && (username.text.trim().isEmpty || password.text.isEmpty))) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Name, designation, username and password are required.'))); return; }
          final data = {'employee_id': 'EMP-${DateTime.now().millisecondsSinceEpoch}', 'full_name': name.text.trim(), 'designation': des.text.trim(), 'contact_number': phone.text.trim(), 'email': email.text.trim(), 'address': address.text.trim(), 'joining_date': '${joining.year}-${joining.month.toString().padLeft(2,'0')}-${joining.day.toString().padLeft(2,'0')}', 'status': status, 'branch_id': bid};
          if (e == null) {
            data['username'] = username.text.trim();
            data['password'] = password.text;
          } else {
            data.remove('branch_id');
            data.remove('employee_id');
            if (username.text.trim().isNotEmpty) data['username'] = username.text.trim();
            if (password.text.isNotEmpty) data['password'] = password.text;
          }
          try { if (e == null) { await api.createEmployee(data); } else { await api.updateEmployee(e.id, data); } if (ctx.mounted) Navigator.pop(ctx); await load(); }
          catch (err) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $err'))); }
        }, child: Text(e == null ? 'Save Employee' : 'Update Employee'))),
      ])),
    )));
    for (final c in [name,des,phone,email,address,username,password]) { c.dispose(); }
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
    backgroundColor: const Color(0xFFFFFBF7),
    appBar: AppBar(
      elevation: 0,
      toolbarHeight: 92,
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      titleSpacing: 20,
      title: const Text('Employees', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE85D04), Color(0xFFFF7A18), Color(0xFFFFA24C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [BoxShadow(color: Color(0x55FF7A18), blurRadius: 26, offset: Offset(0, 9))],
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
      ),
      actions: [
        IconButton(onPressed: load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded, size: 25)),
        const SizedBox(width: 10),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: const Color(0xFFE85D04),
      foregroundColor: Colors.white,
      elevation: 10,
      onPressed: () => editEmployee(),
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Add Employee', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7A18)))
        : RefreshIndicator(
            color: const Color(0xFFFF7A18),
            onRefresh: load,
            child: employees.isEmpty
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFFFFE1CC)),
                          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10))],
                        ),
                        child: Column(children: [
                          Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xFFFFE8D6), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.groups_2_rounded, color: Color(0xFFE85D04), size: 38)),
                          const SizedBox(height: 18),
                          const Text('No employees yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Build your team by adding the first employee to this branch.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
                          const SizedBox(height: 22),
                          FilledButton.icon(onPressed: () => editEmployee(), icon: const Icon(Icons.add), label: const Text('Add Employee')),
                        ]),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                    itemCount: employees.length,
                    itemBuilder: (_, i) {
                      final e = employees[i];
                      final initial = e.fullName.isEmpty ? '?' : e.fullName[0].toUpperCase();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFFFE4D0)),
                          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 7))],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => salaryHistory(e),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(children: [
                              Container(width: 54, height: 54, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFE8D6), Color(0xFFFFD0A8)]), borderRadius: BorderRadius.circular(18)), child: Center(child: Text(initial, style: const TextStyle(color: Color(0xFFE85D04), fontSize: 20, fontWeight: FontWeight.w900)))),
                              const SizedBox(width: 14),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(e.designation, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                                const SizedBox(height: 5),
                                Text('${e.employeeId}  •  ${e.phone}', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                              ])),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                onSelected: (v) async {
                                  if (v == 'edit') await editEmployee(e);
                                  if (v == 'delete') {
                                    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Deactivate employee?'), content: const Text('Financial history will be preserved.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm'))]));
                                    if (ok == true) { await api.deleteEmployee(e.id); await load(); }
                                  }
                                },
                                itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete / Deactivate'))],
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
  );
}
