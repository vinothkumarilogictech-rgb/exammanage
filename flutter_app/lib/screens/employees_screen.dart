import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => EmployeesScreenState();
}

class EmployeesScreenState extends State<EmployeesScreen> {
  final api = DioClient();
  late final BranchContext branchContext;
  List<Employee> employees = [];
  bool loading = true;
  int? _filterBranchId;

  @override
  void initState() {
    super.initState();
    branchContext = context.read<BranchContext>();
    _filterBranchId = branchContext.selectedBranchId;
    branchContext.addListener(_branchChanged);
    load();
  }

  @override
  void dispose() {
    branchContext.removeListener(_branchChanged);
    super.dispose();
  }

  void _branchChanged() {
    if (mounted) {
      setState(() => _filterBranchId = branchContext.selectedBranchId);
      load();
    }
  }

  Future<void> load() async {
    await branchContext.ensureLoaded();
    if (!mounted) return;
    setState(() => loading = true);
    try {
      final r = await api.employees(branchId: _filterBranchId);
      final rows = (r.data['data'] as List? ?? const [])
          .map((x) => Employee.fromMap(Map<String, dynamic>.from(x)))
          .toList();
      if (mounted) setState(() => employees = rows);
    } catch (e) {
      if (mounted) {
        String msg = 'Failed to load employees.';
        if (e is DioException && e.response?.data is Map) {
          msg = e.response!.data['message']?.toString() ?? e.message ?? msg;
        } else {
          msg = e.toString();
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget field(
    TextEditingController c,
    String label, {
    bool enabled = true,
    bool number = false,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      enabled: enabled,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    ),
  );

  Widget _formSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) => Container(
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
        Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...children,
      ],
    ),
  );

  Future<void> editEmployee([Employee? e]) async {
    await branchContext.ensureLoaded();
    final branches = branchContext.branches;

    // Determine initial branch:
    int? selectedBranchId = e?.branchId ?? _filterBranchId ?? branchContext.selectedBranchId;
    if (selectedBranchId == null && branches.isNotEmpty) {
      selectedBranchId = branches.first.id;
    }

    final name = TextEditingController(text: e?.fullName ?? '');
    final des = TextEditingController(text: e?.designation ?? '');
    final phone = TextEditingController(text: e?.phone ?? '');
    final email = TextEditingController(text: e?.email ?? '');
    final address = TextEditingController(text: e?.address ?? '');
    final salary = TextEditingController(
      text: e != null && e.basicSalary > 0
          ? (e.basicSalary % 1 == 0
              ? e.basicSalary.toInt().toString()
              : e.basicSalary.toString())
          : '',
    );
    final username = TextEditingController(text: e?.username ?? '');
    final password = TextEditingController();

    DateTime joining = e == null
        ? DateTime.now()
        : (DateTime.tryParse(e.joiningDate) ?? DateTime.now());
    String status = (e?.status.toLowerCase() == 'inactive') ? 'Inactive' : 'Active';

    String? formError;
    bool isSaving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C1FB0).withOpacity(0.3),
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
                        child: Icon(
                          e == null
                              ? Icons.person_add_alt_1_rounded
                              : Icons.edit_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e == null ? 'Add Employee' : 'Edit Employee',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              e == null
                                  ? 'Add a new team member'
                                  : 'Update details for ${e.fullName}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: isSaving ? null : () => Navigator.pop(ctx, false),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (formError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            formError!,
                            style: const TextStyle(
                              color: Color(0xFFB91C1C),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                _formSectionCard(
                  title: 'PERSONAL DETAILS',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF6C1FB0),
                  children: [
                    field(
                      name,
                      'Full Name *',
                      icon: Icons.person_outline_rounded,
                    ),
                    field(
                      des,
                      'Designation *',
                      icon: Icons.work_outline_rounded,
                    ),
                    field(phone, 'Phone Number', icon: Icons.phone_outlined),
                    field(email, 'Email Address', icon: Icons.email_outlined),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: field(
                        address,
                        'Address',
                        icon: Icons.location_on_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _formSectionCard(
                  title: 'EMPLOYMENT DETAILS',
                  icon: Icons.apartment_rounded,
                  color: const Color(0xFF2563EB),
                  children: [
                    if (branches.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: branches.any((b) => b.id == selectedBranchId)
                                ? selectedBranchId
                                : (branches.isNotEmpty ? branches.first.id : null),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                            items: branches.map((b) => DropdownMenuItem<int>(
                              value: b.id,
                              child: Row(
                                children: [
                                  const Icon(Icons.business_rounded, size: 18, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 10),
                                  Text(b.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                            )).toList(),
                            onChanged: isSaving ? null : (v) {
                              if (v != null) setSheet(() => selectedBranchId = v);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    field(
                      salary,
                      'Basic Salary (₹)',
                      number: true,
                      icon: Icons.currency_rupee_rounded,
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: isSaving ? null : () async {
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: joining,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (d != null) setSheet(() => joining = d);
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 19,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Joining Date: ${joining.year}-${joining.month.toString().padLeft(2, '0')}-${joining.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (e != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: status,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
                            items: const [
                              DropdownMenuItem(
                                value: 'Active',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                                    SizedBox(width: 8),
                                    Text('Status: Active', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Inactive',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel_rounded, size: 16, color: Color(0xFFEF4444)),
                                    SizedBox(width: 8),
                                    Text('Status: Inactive', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: isSaving ? null : (v) {
                              if (v != null) setSheet(() => status = v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                _formSectionCard(
                  title: 'ACCOUNT ACCESS',
                  icon: Icons.lock_outline_rounded,
                  color: const Color(0xFF7C3AED),
                  children: [
                    field(
                      username,
                      e == null ? 'Username *' : 'Username',
                      icon: Icons.alternate_email_rounded,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 0),
                      child: field(
                        password,
                        e == null
                            ? 'Password *'
                            : (e.username != null && e.username!.isNotEmpty
                                ? 'New Password (leave blank to keep current)'
                                : 'Password (optional)'),
                        icon: Icons.key_rounded,
                      ),
                    ),
                    if (e != null && (e.username == null || e.username!.isEmpty)) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 4, left: 4),
                        child: Text(
                          'Note: Enter both username and password to create a login account for this employee.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            e == null
                                ? Icons.person_add_alt_1_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 19,
                          ),
                    onPressed: isSaving
                        ? null
                        : () async {
                            setSheet(() => formError = null);
                            final fullName = name.text.trim();
                            final designation = des.text.trim();
                            final uName = username.text.trim();
                            final pwd = password.text;

                            if (fullName.isEmpty) {
                              setSheet(() => formError = 'Full Name is required.');
                              return;
                            }
                            if (designation.isEmpty) {
                              setSheet(() => formError = 'Designation is required.');
                              return;
                            }
                            if (selectedBranchId == null) {
                              setSheet(() => formError = 'Branch is required.');
                              return;
                            }

                            if (e == null) {
                              if (uName.isEmpty || pwd.isEmpty) {
                                setSheet(() => formError =
                                    'Username and password are required for employee login.');
                                return;
                              }
                            } else {
                              final hadNoLogin = e.username == null || e.username!.isEmpty;
                              if (hadNoLogin && uName.isNotEmpty && pwd.isEmpty) {
                                setSheet(() => formError =
                                    'Both username and password are required to create login.');
                                return;
                              }
                              if (hadNoLogin && pwd.isNotEmpty && uName.isEmpty) {
                                setSheet(() => formError =
                                    'Both username and password are required to create login.');
                                return;
                              }
                            }

                            setSheet(() => isSaving = true);

                            final data = <String, dynamic>{
                              'full_name': fullName,
                              'designation': designation,
                              'contact_number': phone.text.trim(),
                              'email': email.text.trim(),
                              'address': address.text.trim(),
                              'joining_date':
                                  '${joining.year}-${joining.month.toString().padLeft(2, '0')}-${joining.day.toString().padLeft(2, '0')}',
                              'status': status,
                              'branch_id': selectedBranchId,
                            };

                            final salVal = double.tryParse(salary.text.trim());
                            if (salVal != null) {
                              data['basic_salary'] = salVal;
                            } else if (salary.text.trim().isEmpty) {
                              data['basic_salary'] = 0.0;
                            }

                            if (e == null) {
                              data['employee_id'] =
                                  'EMP-${DateTime.now().millisecondsSinceEpoch}';
                              data['username'] = uName;
                              data['password'] = pwd;
                            } else {
                              if (uName.isNotEmpty && uName != (e.username ?? '')) {
                                data['username'] = uName;
                              }
                              if (pwd.isNotEmpty) {
                                data['password'] = pwd;
                              }
                            }

                            try {
                              if (e == null) {
                                await api.createEmployee(data);
                              } else {
                                await api.updateEmployee(e.id, data);
                              }
                              if (ctx.mounted) Navigator.pop(ctx, true);
                            } catch (err) {
                              String message = 'Failed to save employee.';
                              if (err is DioException) {
                                final respData = err.response?.data;
                                if (respData is Map) {
                                  message = respData['message']?.toString() ??
                                      respData['error']?.toString() ??
                                      err.message ??
                                      message;
                                } else if (err.message != null && err.message!.isNotEmpty) {
                                  message = err.message!;
                                }
                              } else {
                                message = err.toString();
                              }
                              if (ctx.mounted) {
                                setSheet(() {
                                  formError = message;
                                  isSaving = false;
                                });
                              }
                            }
                          },
                    label: Text(
                      isSaving
                          ? 'Saving...'
                          : (e == null ? 'Add Employee' : 'Save Changes'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e == null
                ? 'Employee added successfully'
                : 'Employee details updated successfully',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await load();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in [name, des, phone, email, address, salary, username, password]) {
        c.dispose();
      }
    });
  }

  Future<void> salaryHistory(Employee e) async {
    try {
      final r = await api.employeeSalaryHistory(
        e.id,
        branchId: branchContext.selectedBranchId,
      );
      final rows = (r.data['data'] as List? ?? const []);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.fullName,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('${e.employeeId} • ${e.designation}'),
                const Divider(),
                const Text(
                  'Salary History',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No salary payments yet.')),
                  )
                else
                  ...rows.map(
                    (x) => ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: Text('₹ ${x['amount']}'),
                      subtitle: Text(
                        '${x['date_incurred'] ?? ''} • ${x['payment_mode'] ?? ''}',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Widget _buildBranchSelector() {
    final branches = branchContext.branches;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF6C1FB0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF6C1FB0)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: (_filterBranchId == null || branches.any((b) => b.id == _filterBranchId))
                      ? _filterBranchId
                      : null,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6C1FB0)),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Branches', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                    ...branches.map((b) => DropdownMenuItem<int?>(
                      value: b.id,
                      child: Text(b.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    )),
                  ],
                  onChanged: (newId) {
                    setState(() => _filterBranchId = newId);
                    load();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
      title: const Text(
        'Employees',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C1FB0), Color(0xFF9A22C7), Color(0xFFE0189E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x559A22C7),
              blurRadius: 26,
              offset: Offset(0, 9),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Profile',
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
          },
          icon: const Icon(Icons.person_rounded, size: 25),
        ),
        IconButton(
          onPressed: load,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh_rounded, size: 25),
        ),
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
    body: Column(
      children: [
        _buildBranchSelector(),
        Expanded(
          child: loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF9A22C7)),
                )
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
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: const Color(0xFFEDE9FE)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x14000000),
                                    blurRadius: 24,
                                    offset: Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0E3FA),
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    child: const Icon(
                                      Icons.groups_2_rounded,
                                      color: Color(0xFF6C1FB0),
                                      size: 38,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'No employees yet',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Build your team by adding the first employee to this branch.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  FilledButton.icon(
                                    onPressed: () => editEmployee(),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                          itemCount: employees.length,
                          itemBuilder: (_, i) {
                            final e = employees[i];
                            final initial = e.fullName.isEmpty
                                ? '?'
                                : e.fullName[0].toUpperCase();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: CardTint.fill(e.fullName),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: CardTint.border(e.fullName)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x10000000),
                                    blurRadius: 18,
                                    offset: Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(22),
                                onTap: () => salaryHistory(e),
                                child: Padding(
                                  padding: const EdgeInsets.all(15),
                                  child: Row(
                                    children: [
                                      EntityAvatar(
                                        seed: e.fullName,
                                        letter: initial,
                                        size: 54,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              e.fullName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              e.designation,
                                              style: const TextStyle(
                                                color: Color(0xFF6B7280),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              [
                                                e.employeeId,
                                                if (e.phone.isNotEmpty) e.phone,
                                                if (e.username != null && e.username!.isNotEmpty) '@${e.username}',
                                                if (_filterBranchId == null && e.branchName.isNotEmpty) e.branchName,
                                              ].join('  •  '),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: MenuTriggerIcon(color: AvatarPalette.forSeed(e.fullName).first),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        onSelected: (v) async {
                                          if (v == 'edit') await editEmployee(e);
                                          if (v == 'delete') {
                                            final ok = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text(
                                                  'Deactivate employee?',
                                                ),
                                                content: Text(
                                                  'Deactivate "${e.fullName}"? Financial history will be preserved.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context, false),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  FilledButton(
                                                    style: FilledButton.styleFrom(
                                                      backgroundColor: const Color(0xFFE11D48),
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.pop(context, true),
                                                    child: const Text('Deactivate'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (ok == true) {
                                              try {
                                                final r = await api.deleteEmployee(e.id);
                                                final msg = (r.data is Map && r.data['message'] != null)
                                                    ? r.data['message'].toString()
                                                    : 'Employee deactivated successfully.';
                                                if (mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(msg),
                                                      backgroundColor: const Color(0xFF10B981),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                  await load();
                                                }
                                              } catch (err) {
                                                if (mounted) {
                                                  String msg = 'Failed to deactivate employee.';
                                                  if (err is DioException && err.response?.data is Map) {
                                                    msg = err.response!.data['message'] ?? err.message ?? msg;
                                                  }
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text(msg),
                                                      backgroundColor: const Color(0xFFEF4444),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Row(
                                              children: [
                                                Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                                                SizedBox(width: 10),
                                                Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Row(
                                              children: [
                                                Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                                                SizedBox(width: 10),
                                                Text('Delete / Deactivate', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE11D48))),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    ),
  );
}