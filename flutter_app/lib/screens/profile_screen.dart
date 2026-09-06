import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/dio_client.dart';
import '../services/session_service.dart';

const _brand = Color(0xFF9A22C7);
const _brandDark = Color(0xFF6C1FB0);
const _brandSoft = Color(0xFFEDE9FE);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DioClient api = DioClient();

  Map<String, dynamic>? employee;
  List<dynamic> salary = [];

  bool loading = true;
  String? loadError;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final auth = context.read<AuthProvider>();

    try {
      // ----------------------------------------------------------
      // EMPLOYEE PROFILE
      // ----------------------------------------------------------

      if (auth.role == 'Employee' && auth.employeeId != null) {
        final employeeId = auth.employeeId!;

        // Get employee details
        final employeeResponse = await api.employee(employeeId);

        // Get own salary history
        final salaryResponse = await api.employeeSalaryHistory(employeeId);

        // Employee response
        if (employeeResponse.data is Map) {
          final responseData = Map<String, dynamic>.from(employeeResponse.data);

          final data = responseData['data'];

          if (data is Map) {
            employee = Map<String, dynamic>.from(data);
          }
        }

        // Salary response
        if (salaryResponse.data is Map) {
          final responseData = Map<String, dynamic>.from(salaryResponse.data);

          final data = responseData['data'];

          if (data is List) {
            salary = data;
          }
        }
      }
    } catch (e) {
      debugPrint('Profile loading error: $e');

      loadError = 'Unable to load profile information.';
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // ADMIN CREDENTIALS
  // ============================================================

  Future<void> _adminCredentials() async {
    final old = await SessionService.getAdminCredentials();

    final usernameController = TextEditingController(
      text: old['username'] ?? 'admin',
    );

    final passwordController = TextEditingController(
      text: old['password'] ?? '1234',
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Admin Credentials'),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),

            FilledButton(
              onPressed: () async {
                final newUsername = usernameController.text.trim();

                final newPassword = passwordController.text;

                if (newUsername.isEmpty || newPassword.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('User ID and Password are required.'),
                    ),
                  );

                  return;
                }

                await SessionService.saveAdminCredentials(
                  username: newUsername,
                  password: newPassword,
                );

                if (!mounted) return;

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin credentials updated.')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    usernameController.dispose();
    passwordController.dispose();
  }

  // ============================================================
  // LOGOUT CONFIRMATION
  // ============================================================

  Future<void> _confirmLogout(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout from this account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await auth.logout();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // ============================================================
  // EMPLOYEE PROFILE CARD
  // ============================================================

  Widget _employeeDetails() {
    if (employee == null) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Employee details are not available.'),
        ),
      );
    }

    final name = '${employee!['full_name'] ?? ''}';

    final designation = '${employee!['designation'] ?? ''}';

    final email = '${employee!['email'] ?? ''}';

    final phone = '${employee!['contact_number'] ?? ''}';

    final branch = '${employee!['branch_name'] ?? employee!['branch'] ?? ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 16),

            _detailRow(Icons.person_outline, 'Name', name),

            _detailRow(Icons.work_outline, 'Designation', designation),

            if (email.isNotEmpty)
              _detailRow(Icons.email_outlined, 'Email', email),

            if (phone.isNotEmpty)
              _detailRow(Icons.phone_outlined, 'Contact', phone),

            if (branch.isNotEmpty)
              _detailRow(Icons.business_outlined, 'Branch', branch),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const SizedBox(height: 2),

                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SALARY HISTORY
  // ============================================================

  Widget _salaryHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        const Text(
          'My Salary History',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),

        const SizedBox(height: 8),

        if (salary.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No salary payments yet.'),
            ),
          )
        else
          ...salary.map((item) {
            final data = item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{};

            final amount = data['amount'] ?? 0;

            final date = data['date_incurred'] ?? data['date'] ?? '';

            final mode = data['payment_mode'] ?? '';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _brandSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.payments_outlined, color: _brandDark),
                ),
                title: Text(
                  '₹ $amount',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('$date • $mode'),
              ),
            );
          }),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bool isAdmin = auth.role != 'Employee';
    final username = auth.username.isEmpty ? 'User' : auth.username;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(isAdmin ? 'Admin Profile' : 'Employee Profile'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_brandDark, _brand, Color(0xFFE0189E)],
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
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _brand))
          : RefreshIndicator(
              color: _brand,
              onRefresh: _loadProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
                children: [
                  // Hero profile card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_brandDark, _brand, Color(0xFFE0189E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x449A22C7),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.20),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.65),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  auth.role,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  if (loadError != null)
                    _softCard(
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 12),
                          Expanded(child: Text(loadError!)),
                        ],
                      ),
                    ),

                  if (isAdmin) ...[
                    _sectionTitle('Account Settings', Icons.settings_outlined),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Admin Credentials',
                      subtitle: 'Update your User ID and Password',
                      onTap: _adminCredentials,
                    ),
                  ] else ...[
                    _sectionTitle('Personal Information', Icons.badge_outlined),
                    const SizedBox(height: 10),
                    _employeeDetails(),
                    _salaryHistory(),
                  ],

                  const SizedBox(height: 18),
                  _sectionTitle('Account', Icons.manage_accounts_outlined),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEDE9FE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x189A22C7),
                          blurRadius: 16,
                          offset: Offset(0, 7),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _brandSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: _brandDark,
                        ),
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text('Sign out from this account'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _confirmLogout(auth),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _brandDark, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _softCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE9FE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x169A22C7),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _softCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _brandSoft,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: _brandDark),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
