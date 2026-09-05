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

  Widget field(TextEditingController c, String label, {bool enabled = true, bool number = false, IconData? icon}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      enabled: enabled,
      keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      ),
    ),
  );

  Widget _formSectionCard({required String title, required IconData icon, required Color color, required List<Widget> children}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFEFEFEF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.3)),
        ]),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Future<void> editEmployee([Employee? e]) async {
    final bid = branchContext.selectedBranchId;
    if (bid == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a branch from Dashboard first.'))); return; }
    final name = TextEditingController(text: e?.fullName ?? ''), des = TextEditingController(text: e?.designation ?? ''), phone = TextEditingController(text: e?.phone ?? ''), email = TextEditingController(text: e?.email ?? ''), address = TextEditingController(text: e?.address ?? ''), username = TextEditingController(), password = TextEditingController();
    DateTime joining = e == null ? DateTime.now() : (DateTime.tryParse(e.joiningDate) ?? DateTime.now());
    String status = e?.status ?? 'Active';
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9A22C7), Color(0xFF6C1FB0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: const Color(0xFF6C1FB0).withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
                      child: Icon(e == null ? Icons.person_add_alt_1_rounded : Icons.edit_rounded, color: Colors.white, size: 23),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(e == null ? 'Add' : 'Edit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(
                          e == null ? 'Add a new team member to this branch' : 'Update employee details',
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70),
                        ),
                      ]),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                _formSectionCard(
                  title: 'PERSONAL DETAILS',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF6C1FB0),
                  children: [
                    field(name, 'Full Name *', icon: Icons.person_outline_rounded),
                    field(des, 'Designation *', icon: Icons.work_outline_rounded),
                    field(phone, 'Phone', icon: Icons.phone_outlined),
                    field(email, 'Email', icon: Icons.email_outlined),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: field(address, 'Address', icon: Icons.location_on_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _formSectionCard(
                  title: 'ACCOUNT ACCESS',
                  icon: Icons.lock_outline_rounded,
                  color: const Color(0xFF7C3AED),
                  children: [
                    field(username, e == null ? 'Username *' : 'Username (optional)', icon: Icons.alternate_email_rounded),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: field(password, e == null ? 'Password *' : 'Password (optional)', icon: Icons.key_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _formSectionCard(
                  title: 'EMPLOYMENT DETAILS',
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF2563EB),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business_rounded, size: 20, color: Color(0xFF6B7280)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            branchContext.selectedBranchName ?? 'Selected branch',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final d = await showDatePicker(context: ctx, initialDate: joining, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (d != null) setSheet(() => joining = d);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_today_rounded, size: 19, color: Color(0xFF6B7280)),
                          const SizedBox(width: 10),
                          Text(
                            'Joining: ${joining.year}-${joining.month.toString().padLeft(2, '0')}-${joining.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ]),
                      ),
                    ),
                    if (e != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: status,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (v) {
                              if (v != null) setSheet(() => status = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C1FB0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    icon: Icon(e == null ? Icons.person_add_alt_1_rounded : Icons.check_circle_outline_rounded, size: 19),
                    onPressed: () async {
                      if (name.text.trim().isEmpty || des.text.trim().isEmpty || (e == null && (username.text.trim().isEmpty || password.text.isEmpty))) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Name, designation, username and password are required.')));
                        return;
                      }
                      final data = {
                        'employee_id': 'EMP-${DateTime.now().millisecondsSinceEpoch}',
                        'full_name': name.text.trim(),
                        'designation': des.text.trim(),
                        'contact_number': phone.text.trim(),
                        'email': email.text.trim(),
                        'address': address.text.trim(),
                        'joining_date': '${joining.year}-${joining.month.toString().padLeft(2, '0')}-${joining.day.toString().padLeft(2, '0')}',
                        'status': status,
                        'branch_id': bid,
                      };
                      if (e == null) {
                        data['username'] = username.text.trim();
                        data['password'] = password.text;
                      } else {
                        data.remove('branch_id');
                        data.remove('employee_id');
                        if (username.text.trim().isNotEmpty) data['username'] = username.text.trim();
                        if (password.text.isNotEmpty) data['password'] = password.text;
                      }
                      try {
                        if (e == null) {
                          await api.createEmployee(data);
                        } else {
                          await api.updateEmployee(e.id, data);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        await load();
                      } catch (err) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $err')));
                      }
                    },
                    label: Text(e == null ? 'Add' : 'Save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    backgroundColor: const Color(0xFFF7F5FD),
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
            colors: [Color(0xFF6C1FB0), Color(0xFF9A22C7), Color(0xFFE0189E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [BoxShadow(color: Color(0x559A22C7), blurRadius: 26, offset: Offset(0, 9))],
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
      ),
      actions: [
        IconButton(onPressed: load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded, size: 25)),
        const SizedBox(width: 10),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      backgroundColor: const Color(0xFF6C1FB0),
      foregroundColor: Colors.white,
      elevation: 10,
      onPressed: () => editEmployee(),
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF9A22C7)))
        : RefreshIndicator(
            color: const Color(0xFF9A22C7),
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
                          border: Border.all(color: const Color(0xFFEDE9FE)),
                          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10))],
                        ),
                        child: Column(children: [
                          Container(width: 76, height: 76, decoration: BoxDecoration(color: const Color(0xFFF0E3FA), borderRadius: BorderRadius.circular(24)), child: const Icon(Icons.groups_2_rounded, color: Color(0xFF6C1FB0), size: 38)),
                          const SizedBox(height: 18),
                          const Text('No employees yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          const Text('Build your team by adding the first employee to this branch.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280), height: 1.4)),
                          const SizedBox(height: 22),
                          FilledButton.icon(onPressed: () => editEmployee(), icon: const Icon(Icons.add), label: const Text('Add')),
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
                          border: Border.all(color: const Color(0xFFEDE9FE)),
                          boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 18, offset: Offset(0, 7))],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => salaryHistory(e),
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Row(children: [
                              Container(width: 54, height: 54, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF0E3FA), Color(0xFFD8B4FE)]), borderRadius: BorderRadius.circular(18)), child: Center(child: Text(initial, style: const TextStyle(color: Color(0xFF6C1FB0), fontSize: 20, fontWeight: FontWeight.w900)))),
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