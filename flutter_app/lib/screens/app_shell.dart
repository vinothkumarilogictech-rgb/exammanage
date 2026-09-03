import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'dashboard_screen.dart';
import 'branches_screen.dart';
import 'exams_screen.dart';
import 'expenses_screen.dart';
import 'vouchers_screen.dart';
import 'employees_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  final _dashboardKey = GlobalKey<DashboardScreenState>();
  final _expenseKey = GlobalKey<ExpensesScreenState>();

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();
      pages = [
    DashboardScreen(key: _dashboardKey),
    const BranchesScreen(),
    const ExamsScreen(),
    ExpensesScreen(key: _expenseKey),
    const VouchersScreen(),
    EmployeesScreen(),
  ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
          onDestinationSelected: (v) {
    setState(() => index = v);

    if (v == 0) {
      _dashboardKey.currentState?.reload();
    }
  },
        height: 72,
        indicatorColor: const Color(0xFFE8E4FF),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Branches',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Exams',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expense',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_num_outlined),
            selectedIcon: Icon(Icons.confirmation_num),
            label: 'Vouchers',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge),
            label: 'Employees',
          ),
        ],
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const BranchesScreen(openAddOnStart: true),
                ),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
