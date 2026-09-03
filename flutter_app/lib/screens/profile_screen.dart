import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../services/dio_client.dart';
import '../services/session_service.dart';

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
        final employeeResponse =
            await api.employee(employeeId);

        // Get own salary history
        final salaryResponse =
            await api.employeeSalaryHistory(employeeId);

        // Employee response
        if (employeeResponse.data is Map) {
          final responseData =
              Map<String, dynamic>.from(
            employeeResponse.data,
          );

          final data = responseData['data'];

          if (data is Map) {
            employee =
                Map<String, dynamic>.from(data);
          }
        }

        // Salary response
        if (salaryResponse.data is Map) {
          final responseData =
              Map<String, dynamic>.from(
            salaryResponse.data,
          );

          final data = responseData['data'];

          if (data is List) {
            salary = data;
          }
        }
      }
    } catch (e) {
      debugPrint(
        'Profile loading error: $e',
      );

      loadError =
          'Unable to load profile information.';
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
    final old =
        await SessionService.getAdminCredentials();

    final usernameController =
        TextEditingController(
      text: old['username'] ?? 'admin',
    );

    final passwordController =
        TextEditingController(
      text: old['password'] ?? '1234',
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Admin Credentials',
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  prefixIcon:
                      Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon:
                      Icon(Icons.lock_outline),
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
                final newUsername =
                    usernameController.text.trim();

                final newPassword =
                    passwordController.text;

                if (newUsername.isEmpty ||
                    newPassword.isEmpty) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'User ID and Password are required.',
                      ),
                    ),
                  );

                  return;
                }

                await SessionService
                    .saveAdminCredentials(
                  username: newUsername,
                  password: newPassword,
                );

                if (!mounted) return;

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Admin credentials updated.',
                    ),
                  ),
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
  // EMPLOYEE PROFILE CARD
  // ============================================================

  Widget _employeeDetails() {
    if (employee == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Employee details are not available.',
          ),
        ),
      );
    }

    final name =
        '${employee!['full_name'] ?? ''}';

    final designation =
        '${employee!['designation'] ?? ''}';

    final email =
        '${employee!['email'] ?? ''}';

    final phone =
        '${employee!['contact_number'] ?? ''}';

    final branch =
        '${employee!['branch_name'] ?? employee!['branch'] ?? ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 16),

            _detailRow(
              Icons.person_outline,
              'Name',
              name,
            ),

            _detailRow(
              Icons.work_outline,
              'Designation',
              designation,
            ),

            if (email.isNotEmpty)
              _detailRow(
                Icons.email_outlined,
                'Email',
                email,
              ),

            if (phone.isNotEmpty)
              _detailRow(
                Icons.phone_outlined,
                'Contact',
                phone,
              ),

            if (branch.isNotEmpty)
              _detailRow(
                Icons.business_outlined,
                'Branch',
                branch,
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),

        const Text(
          'My Salary History',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        if (salary.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No salary payments yet.',
              ),
            ),
          )
        else
          ...salary.map(
            (item) {
              final data =
                  item is Map
                      ? Map<String, dynamic>.from(item)
                      : <String, dynamic>{};

              final amount =
                  data['amount'] ?? 0;

              final date =
                  data['date_incurred'] ??
                      data['date'] ??
                      '';

              final mode =
                  data['payment_mode'] ?? '';

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 8,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons
                          .payments_outlined,
                    ),
                  ),
                  title: Text(
                    '₹ $amount',
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    '$date • $mode',
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final auth =
        context.watch<AuthProvider>();

    final bool isAdmin =
        auth.role != 'Employee';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin
              ? 'Admin Profile'
              : 'Employee Profile',
        ),
      ),

      body: loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : ListView(
              padding:
                  const EdgeInsets.all(20),

              children: [
                // ------------------------------------------------
                // USER HEADER
                // ------------------------------------------------

                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),

                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [
                        Text(
                          auth.username.isEmpty
                              ? '-'
                              : auth.username,

                          style:
                              const TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          auth.role,
                          style:
                              const TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ------------------------------------------------
                // ERROR
                // ------------------------------------------------

                if (loadError != null)
                  Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(16),

                      child: Text(
                        loadError!,
                        style:
                            const TextStyle(
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),

                // ------------------------------------------------
                // ADMIN
                // ------------------------------------------------

                if (isAdmin)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons
                            .admin_panel_settings_outlined,
                      ),

                      title: const Text(
                        'Change User ID / Password',
                      ),

                      subtitle: const Text(
                        'Update admin login credentials',
                      ),

                      trailing: const Icon(
                        Icons.chevron_right,
                      ),

                      onTap:
                          _adminCredentials,
                    ),
                  ),

                // ------------------------------------------------
                // EMPLOYEE
                // ------------------------------------------------

                if (!isAdmin) ...[
                  _employeeDetails(),

                  _salaryHistory(),
                ],

                const SizedBox(
                  height: 20,
                ),

                // ------------------------------------------------
                // LOGOUT
                // ------------------------------------------------

                FilledButton.tonalIcon(
                  onPressed: () async {
                    await auth.logout();
                  },

                  icon: const Icon(
                    Icons.logout,
                  ),

                  label: const Text(
                    'Logout',
                  ),
                ),
              ],
            ),
    );
  }
}