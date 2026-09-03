import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'branches_screen.dart';
import 'exams_screen.dart';
import 'expenses_screen.dart';
import 'vouchers_screen.dart';
import 'employees_screen.dart';
import 'profile_screen.dart';

class AppShell extends StatefulWidget { const AppShell({super.key}); @override State<AppShell> createState() => _AppShellState(); }
class _AppShellState extends State<AppShell> {
  int index=0; final _dashboardKey=GlobalKey<DashboardScreenState>(); final _expenseKey=GlobalKey<ExpensesScreenState>(); late List<Widget> pages;
  @override void initState(){super.initState(); final employee=context.read<AuthProvider>().role.toLowerCase()=='employee'; pages=[DashboardScreen(key:_dashboardKey),const BranchesScreen(),const ExamsScreen(),if(!employee) ExpensesScreen(key:_expenseKey),if(!employee) const VouchersScreen(),if(!employee) EmployeesScreen()];}
  void profile(){Navigator.push(context,MaterialPageRoute(builder:(_)=>const ProfileScreen()));}
  @override Widget build(BuildContext context){ final auth=context.watch<AuthProvider>(); return Scaffold(body:IndexedStack(index:index,children:pages),bottomNavigationBar:NavigationBar(backgroundColor:const Color(0xFFFFF7F0),indicatorColor:const Color(0xFFFFE0C2),selectedIndex:index,onDestinationSelected:(v){setState(()=>index=v);if(v==0)_dashboardKey.currentState?.reload();},height:72,destinations:[const NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Dashboard'),const NavigationDestination(icon:Icon(Icons.account_tree_outlined),selectedIcon:Icon(Icons.account_tree),label:'Branches'),const NavigationDestination(icon:Icon(Icons.school_outlined),selectedIcon:Icon(Icons.school),label:'Exams'),if(auth.role!='Employee')const NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'Expense'),if(auth.role!='Employee')const NavigationDestination(icon:Icon(Icons.confirmation_num_outlined),selectedIcon:Icon(Icons.confirmation_num),label:'Vouchers'),if(auth.role!='Employee')const NavigationDestination(icon:Icon(Icons.badge_outlined),selectedIcon:Icon(Icons.badge),label:'Employees')]),floatingActionButton:index==1?FloatingActionButton(backgroundColor:AppColors.primary,foregroundColor:Colors.white,onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BranchesScreen(openAddOnStart:true))),child:const Icon(Icons.add)):null); }
}