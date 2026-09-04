import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../app_theme.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';
import '../providers/branch_context.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ExpensesScreen extends StatefulWidget {
  final bool openAddOnStart;
  const ExpensesScreen({super.key, this.openAddOnStart = false});

  @override
  State<ExpensesScreen> createState() => ExpensesScreenState();
}

class ExpensesScreenState extends State<ExpensesScreen> {
  final api = DioClient();

  // Tab: 0 = Expenses, 1 = Categories
  int _selectedTab = 0;

  // Expenses state
  List<Expense> _allExpenses = [];
  List<Expense> _filteredExpenses = [];
  List<Branch> _branches = [];
  List<ExpenseCategoryItem> _categories = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search & Period filter values (Search, Branch, Days / Week / Month)
  final TextEditingController _searchCtrl = TextEditingController();
  int? _selectedBranchId; // null = All Branches
  int? _selectedCategoryId; // null = All Categories
  String _selectedPeriod = 'All'; // 'All', 'Days', 'Week', 'Month'
  DateTime? _selectedExpenseDate; // null = all dates

  // Category tab form controller
  final TextEditingController _newCategoryCtrl = TextEditingController();
  bool _isAddingCategory = false;

  // Calculated stats
  double _totalExpenses = 0.0;
  double _thisMonthExpenses = 0.0;
  double _thisQuarterExpenses = 0.0;
  double _thisYearExpenses = 0.0;

  static const List<String> _paymentModes = [
    'Cash',
    'UPI',
    'Card',
    'Net Banking',
    'Bank Transfer',
    'Cheque',
    'Other',
  ];

  static const List<String> _periodOptions = [
    'All',
    'Days',
    'Week',
    'Month',
  ];

  bool _opened = false;
  late final BranchContext _branchContext;

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.openAddOnStart && !_opened) {
      _opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => addExpense());
    }
  }

  void _onBranchChanged() {
    if (!mounted) return;
    _loadInitialData();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    _searchCtrl.dispose();
    _newCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _branchContext.ensureLoaded();
      final globalBranchId = _branchContext.selectedBranchId;
      final results = await Future.wait([
        api.expenses(branchId: globalBranchId),
        api.branches(),
        api.expenseCategories(),
        api.employees(branchId: globalBranchId, status: 'Active'),
      ]);

      final expensesResp = results[0];
      final branchesResp = results[1];
      final categoriesResp = results[2];
      final employeesResp = results[3];

      final expensesList = (expensesResp.data['data'] as List? ?? const [])
          .map((x) => Expense.fromMap(Map<String, dynamic>.from(x)))
          .toList();

      final branchesList = (branchesResp.data['data'] as List? ?? const [])
          .map((x) => Branch.fromMap(Map<String, dynamic>.from(x)))
          .toList();

      final categoriesList = (categoriesResp.data['data'] as List? ?? const [])
          .map((x) => ExpenseCategoryItem.fromMap(Map<String, dynamic>.from(x)))
          .where((c) => c.name.trim().toLowerCase() != 'marketing')
          .toList();

      // Sort categories alphabetically A-Z with 'Other' placed at the very end
      categoriesList.sort((a, b) {
        final aIsOther = a.name.trim().toLowerCase() == 'other';
        final bIsOther = b.name.trim().toLowerCase() == 'other';
        if (aIsOther && !bIsOther) return 1;
        if (!aIsOther && bIsOther) return -1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _allExpenses = expensesList;
      _branches = branchesList;
      _selectedBranchId = globalBranchId;
      _categories = categoriesList;
      final employeesList = (employeesResp.data['data'] as List? ?? const [])
          .map((x) => Employee.fromMap(Map<String, dynamic>.from(x)))
          .toList();

      _employees = employeesList;

      _calculateStats(expensesList);
      _applyLocalFilters();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: $e';
        });
      }
    }
  }

  Future<void> reload() => _loadInitialData();

  void _calculateStats(List<Expense> list) {
    final now = DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;
    final currentQuarter = (currentMonth - 1) ~/ 3;

    double total = 0.0;
    double month = 0.0;
    double quarter = 0.0;
    double year = 0.0;

    for (final e in list) {
      if (e.status == 'Cancelled') continue;
      total += e.amount;

      DateTime? dt = _parseDate(e.date);
      if (dt != null) {
        if (dt.year == currentYear) {
          year += e.amount;
          if (dt.month == currentMonth) {
            month += e.amount;
          }
          final q = (dt.month - 1) ~/ 3;
          if (q == currentQuarter) {
            quarter += e.amount;
          }
        }
      }
    }

    _totalExpenses = total;
    _thisMonthExpenses = month;
    _thisQuarterExpenses = quarter;
    _thisYearExpenses = year;
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      if (raw.contains('T')) {
        return DateTime.parse(raw);
      }
      final parts = raw.trim().split('-');
      if (parts.length >= 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2].split(' ')[0]),
        );
      }
    } catch (_) {}
    return null;
  }

  String _monthShortName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }

  String _formatDateDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    final dt = _parseDate(raw);
    if (dt == null) return raw;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day.toString().padLeft(2, '0')}-${months[dt.month - 1]}-${dt.year}';
  }

  Future<void> _pickExpenseFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpenseDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'FILTER EXPENSES BY DATE',
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedExpenseDate = DateTime(picked.year, picked.month, picked.day);
      // A selected calendar date is an exact-date filter, so reset the
      // relative period filter to avoid combining two date ranges.
      _selectedPeriod = 'All';
      _applyLocalFilters();
    });
  }

  void _clearExpenseFilterDate() {
    if (_selectedExpenseDate == null) return;
    setState(() {
      _selectedExpenseDate = null;
      _applyLocalFilters();
    });
  }

  void _applyLocalFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final now = DateTime.now();

    // Bounds for Days (Today)
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    // Bounds for Week (Current Week Monday to Sunday)
    final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

    // Bounds for Month (Current Month)
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    _filteredExpenses = _allExpenses.where((e) {
      // 1. Branch filter (All Branches or specific branch)
      if (_selectedBranchId != null) {
        if (e.branchId != null && e.branchId != _selectedBranchId) {
          return false;
        }
        if (e.branchId == null) {
          final branchObj = _branches.firstWhere(
            (b) => b.id == _selectedBranchId,
            orElse: () => Branch(id: -1, name: '', address: '', contact: '', region: '', status: ''),
          );
          if (branchObj.id != -1 && e.branch.toLowerCase() != branchObj.name.toLowerCase()) {
            return false;
          }
        }
      }

      // 2. Category filter (All Categories or a specific category)
      if (_selectedCategoryId != null) {
        if (e.categoryId != null && e.categoryId != _selectedCategoryId) {
          return false;
        }
        if (e.categoryId == null) {
          final categoryObj = _categories.firstWhere(
            (c) => c.id == _selectedCategoryId,
            orElse: () => ExpenseCategoryItem(
              id: -1,
              name: '',
              status: '',
              createdAt: '',
            ),
          );
          if (categoryObj.id != -1 &&
              e.category.toLowerCase() != categoryObj.name.toLowerCase()) {
            return false;
          }
        }
      }

      // 3. Period Filter: 'All', 'Days' (Today), 'Week', 'Month'
      final dt = _parseDate(e.date);

      // 2a. Exact calendar-date filter.
      if (_selectedExpenseDate != null) {
        if (dt == null) return false;
        final expenseDay = DateTime(dt.year, dt.month, dt.day);
        if (expenseDay != _selectedExpenseDate) return false;
      }

      if (_selectedPeriod != 'All' && dt != null) {
        if (_selectedPeriod == 'Days') {
          if (dt.isBefore(todayStart) || dt.isAfter(todayEnd)) return false;
        } else if (_selectedPeriod == 'Week') {
          if (dt.isBefore(weekStart) || dt.isAfter(weekEnd)) return false;
        } else if (_selectedPeriod == 'Month') {
          if (dt.isBefore(monthStart) || dt.isAfter(monthEnd)) return false;
        }
      }

      // 4. Search Query (Matches category, description, branch, payment mode, amount)
      if (query.isNotEmpty) {
        final matchCategory = e.category.toLowerCase().contains(query);
        final matchDescription = e.description.toLowerCase().contains(query);
        final matchPaymentMode = e.paymentMode.toLowerCase().contains(query);
        final matchBranch = e.branch.toLowerCase().contains(query);
        final matchAmount = e.amount.toString().contains(query);
        if (!matchCategory && !matchDescription && !matchPaymentMode && !matchBranch && !matchAmount) {
          return false;
        }
      }

      return true;
    }).toList();

    _calculateStats(_filteredExpenses);
  }

  // --- Category Actions ---
  Future<void> _addCategory() async {
    final name = _newCategoryCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter category name')),
      );
      return;
    }

    setState(() => _isAddingCategory = true);
    try {
      await api.createExpenseCategory(name);
      _newCategoryCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$name" created successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
      await reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating category: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingCategory = false);
    }
  }

  Future<void> _toggleCategoryStatus(ExpenseCategoryItem cat) async {
    final newStatus = cat.status == 'Active' ? 'Inactive' : 'Active';
    try {
      await api.toggleExpenseCategory(cat.id, status: newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "${cat.name}" is now $newStatus.'),
            backgroundColor: newStatus == 'Active' ? AppColors.green : Colors.grey[800],
          ),
        );
      }
      await reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating category: $e')),
        );
      }
    }
  }

  Widget _formSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) =>
      Container(
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

  // --- Add Expense Modal ---
  Future<void> addExpense() async {
    final globalBranchId = _branchContext.selectedBranchId;
    if (globalBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a branch from Dashboard before adding an expense.')));
      return;
    }
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    int? branchId = globalBranchId;
    int? categoryId = _categories.isNotEmpty ? _categories.first.id : null;
    int? employeeId;
    String paymentMode = 'Cash';
    DateTime selectedDate = DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF7A18), Color(0xFFE85D04)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33E85D04), blurRadius: 14, offset: Offset(0, 6)),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Record a new branch expense',
                            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(ctx),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                _formSectionCard(
                  title: 'EXPENSE CATEGORY',
                  icon: Icons.sell_rounded,
                  color: const Color(0xFFE85D04),
                  children: [
                    const Text(
                      'Category *',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: categoryId,
                          hint: const Text('Select Category'),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: _categories.where((c) => context.read<AuthProvider>().role != 'Employee' || !['salary','salaries'].contains(c.name.trim().toLowerCase())).map((c) {
                            return DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => categoryId = val);
                            }
                          },
                        ),
                      ),
                    ),
                    if (categoryId != null && _categories.any((c) => c.id == categoryId && ['salary', 'salaries'].contains(c.name.trim().toLowerCase()))) ...[
                      const SizedBox(height: 14),
                      const Text('Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                      const SizedBox(height: 6),
                      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))), padding: const EdgeInsets.symmetric(horizontal: 12), child: DropdownButtonHideUnderline(child: DropdownButton<int>(isExpanded: true, value: employeeId, hint: const Text('Select Employee'), items: _employees.map((e) => DropdownMenuItem<int>(value: e.id, child: Text('${e.employeeId} - ${e.fullName}'))).toList(), onChanged: (v) => setSheetState(() => employeeId = v)))),
                    ],
                  ],
                ),
                const SizedBox(height: 14),

                _formSectionCard(
                  title: 'PAYMENT DETAILS',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF7C3AED),
                  children: [
                    const Text(
                      'Branch',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.business_rounded, size: 20, color: Color(0xFF6B7280)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          _branches.where((b) => b.id == globalBranchId).isNotEmpty
                              ? _branches.firstWhere((b) => b.id == globalBranchId).name
                              : 'Selected Branch',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        )),
                        const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
                      ]),
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode Dropdown
                    const Text(
                      'Payment Mode *',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
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
                          value: paymentMode,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          items: _paymentModes
                              .map((m) => DropdownMenuItem<String>(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setSheetState(() => paymentMode = val);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date Incurred
                    const Text(
                      'Date Incurred',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setSheetState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF6B7280)),
                            const SizedBox(width: 10),
                            Text(
                              '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount
                    const Text(
                      'Amount *',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                        filled: true,
                        fillColor: Colors.white,
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
                  ],
                ),
                const SizedBox(height: 14),

                _formSectionCard(
                  title: 'NOTES',
                  icon: Icons.notes_rounded,
                  color: const Color(0xFF6B7280),
                  children: [
                    const Text(
                      'Description / Note',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter expense note or description',
                        prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                        filled: true,
                        fillColor: Colors.white,
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
                  ],
                ),
                const SizedBox(height: 24),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 19),
                    onPressed: () async {
                      final val = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (val <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }

                      final catObj = _categories.firstWhere(
                        (c) => c.id == categoryId,
                        orElse: () => ExpenseCategoryItem(id: 0, name: 'Other', status: 'Active', createdAt: ''),
                      );

                      final isSalary = categoryId != null && _categories.any((c) => c.id == categoryId && ['salary', 'salaries'].contains(c.name.trim().toLowerCase()));
                      if (isSalary && employeeId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select an employee for salary expense.')));
                        return;
                      }

                      try {
                        await api.createExpense({
                          'amount': val,
                          'category_id': categoryId,
                          'category': catObj.name,
                          'branch_id': branchId,
                          'employee_id': employeeId,
                          'payment_mode': paymentMode,
                          'description': noteCtrl.text.trim(),
                          'date_incurred': selectedDate.toIso8601String(),
                          'status': 'Active',
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Expense added successfully!'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                            reload();
                          }
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    label: const Text(
                      'Add',
                      style: TextStyle(
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
  }

  // --- Edit Expense Modal ---
  Future<void> _editExpense(Expense e) async {
    final amountCtrl = TextEditingController(text: e.amount.toString());
    final noteCtrl = TextEditingController(text: e.description);
    int? branchId = e.branchId;
    int? categoryId = e.categoryId;
    if (categoryId == null && _categories.isNotEmpty) {
      final found = _categories.where((c) => c.name.toLowerCase() == e.category.toLowerCase()).toList();
      if (found.isNotEmpty) categoryId = found.first.id;
    }
    int? employeeId = e.employeeId;
    String paymentMode = e.paymentMode.isNotEmpty ? e.paymentMode : 'Cash';
    String status = e.status.isNotEmpty ? e.status : 'Active';
    DateTime selectedDate = _parseDate(e.date) ?? DateTime.now();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: Color(0xFFE85D04),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Expense',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Amount
                const Text('Amount *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.currency_rupee_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Category
                const Text('Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: categoryId,
                      items: _categories.where((c) => context.read<AuthProvider>().role != 'Employee' || !['salary','salaries'].contains(c.name.trim().toLowerCase())).map((c) {
                        return DropdownMenuItem<int?>(
                          value: c.id,
                          child: Text(c.name),
                        );
                      }).toList(),
                      onChanged: (val) => setSheetState(() => categoryId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (categoryId != null && _categories.any((c) => c.id == categoryId && ['salary', 'salaries'].contains(c.name.trim().toLowerCase()))) ...[
                  const Text('Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: employeeId,
                        hint: const Text('Select Employee'),
                        items: _employees.map((emp) => DropdownMenuItem<int>(value: emp.id, child: Text('${emp.employeeId} - ${emp.fullName}'))).toList(),
                        onChanged: (v) => setSheetState(() => employeeId = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Branch
                const Text('Branch', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: branchId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('- None / General -')),
                        ..._branches.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: (val) => setSheetState(() => branchId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Mode & Status Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Payment Mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: paymentMode,
                                items: _paymentModes
                                    .map((m) => DropdownMenuItem<String>(value: m, child: Text(m)))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) setSheetState(() => paymentMode = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: status,
                                items: const [
                                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setSheetState(() => status = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date Incurred
                const Text('Date Incurred', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setSheetState(() => selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, size: 20, color: Color(0xFF6B7280)),
                        const SizedBox(width: 10),
                        Text(
                          '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Description
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
                const SizedBox(height: 6),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save Updates Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE85D04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final val = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (val <= 0) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid amount')),
                        );
                        return;
                      }

                      final catObj = _categories.firstWhere(
                        (c) => c.id == categoryId,
                        orElse: () => ExpenseCategoryItem(id: 0, name: e.category, status: 'Active', createdAt: ''),
                      );
                      final isSalary = ['salary', 'salaries'].contains(catObj.name.trim().toLowerCase());
                      if (isSalary && employeeId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please select an employee for salary expense.')));
                        return;
                      }

                      try {
                        await api.updateExpense(e.id, {
                          'amount': val,
                          'category_id': categoryId,
                          'category': catObj.name,
                          'branch_id': branchId,
                          'employee_id': employeeId,
                          'payment_mode': paymentMode,
                          'description': noteCtrl.text.trim(),
                          'date_incurred': selectedDate.toIso8601String(),
                          'status': status,
                        });

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Expense updated successfully!'),
                                backgroundColor: AppColors.green,
                              ),
                            );
                            reload();
                          }
                        }
                      } catch (err) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $err')),
                          );
                        }
                      }
                    },
                    child: const Text('Update Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- View Expense Detail Modal ---
  void _viewExpense(Expense e) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Color(0xFFE85D04),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Expense Details',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: e.status == 'Cancelled' ? const Color(0xFFFEE2E2) : const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    e.status,
                    style: TextStyle(
                      color: e.status == 'Cancelled' ? const Color(0xFFDC2626) : const Color(0xFF5B21B6),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: Column(
                children: [
                  _detailRow('Amount', '₹${e.amount.toStringAsFixed(2)}', isBold: true, fontSize: 18),
                  const Divider(height: 20, color: Color(0xFFE5E7EB)),
                  _detailRow('Category', e.category),
                  const SizedBox(height: 8),
                  _detailRow('Date', _formatDateDisplay(e.date)),
                  const SizedBox(height: 8),
                  _detailRow('Branch', e.branch.isNotEmpty ? e.branch : '-'),
                  if (e.employeeName.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Employee', e.employeeName),
                  ],
                  const SizedBox(height: 8),
                  _detailRow('Payment Mode', e.paymentMode.isNotEmpty ? e.paymentMode : '-'),
                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Description', e.description),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7A18),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editExpense(e);
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: const Color(0xFF111827),
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ),
      ],
    );
  }

  // --- Print options (Export PDF / Export Excel) ---
  Future<void> _showPrintOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const Text(
              'Print',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFE85D04), size: 20),
              ),
              title: const Text('Export PDF', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportPdf();
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_chart_rounded, color: Color(0xFFE85D04), size: 20),
              ),
              title: const Text('Export Excel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportExcel();
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- PDF Export ---
  Future<void> _exportPdf() async {
    final pdf = pw.Document();

    // Calculate total of the filtered expenses only (for the selected branch/filter)
    final filteredTotal = _filteredExpenses
        .where((e) => e.status != 'Cancelled')
        .fold(0.0, (sum, e) => sum + e.amount);

    String branchLabel = 'All Branches';
    if (_selectedBranchId != null) {
      final b = _branches.firstWhere(
        (x) => x.id == _selectedBranchId,
        orElse: () => Branch(id: -1, name: '', address: '', contact: '', region: '', status: ''),
      );
      if (b.name.isNotEmpty) {
        branchLabel = b.name;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Expense Management Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_formatDateDisplay(DateTime.now().toIso8601String()), style: const pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Branch: $branchLabel', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('Filter Period: $_selectedPeriod', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Total Expenses: Rs ${filteredTotal.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.purple900)),
                pw.Text('Total Records: ${_filteredExpenses.length}', style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Branch', 'Category', 'Amount (Rs)', 'Payment Mode', 'Status'],
              data: _filteredExpenses.map((e) {
                return [
                  _formatDateDisplay(e.date),
                  e.branch.isNotEmpty ? e.branch : '-',
                  e.category,
                  e.amount.toStringAsFixed(2),
                  e.paymentMode,
                  e.status,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE85D04)),
              cellAlignment: pw.Alignment.centerLeft,
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
            ),
          ];
        },
      ),
    );

    final filenameSuffix = _selectedBranchId != null ? '_${branchLabel.replaceAll(' ', '_')}' : '';
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'expense_report${filenameSuffix}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // --- Excel / CSV Export ---
  Future<void> _exportExcel() async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Branch,Category,Amount,Payment Mode,Status,Description');

    for (final e in _filteredExpenses) {
      final date = _formatDateDisplay(e.date);
      final branch = '"${e.branch.replaceAll('"', '""')}"';
      final cat = '"${e.category.replaceAll('"', '""')}"';
      final amt = e.amount.toStringAsFixed(2);
      final pm = '"${e.paymentMode.replaceAll('"', '""')}"';
      final st = '"${e.status.replaceAll('"', '""')}"';
      final desc = '"${e.description.replaceAll('"', '""')}"';
      buffer.writeln('$date,$branch,$cat,$amt,$pm,$st,$desc');
    }

    final bytes = Uint8List.fromList(buffer.toString().codeUnits);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'expense_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF7),
      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE85D04), Color(0xFFFF7A18), Color(0xFFFF9F43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [BoxShadow(color: Color(0x55FF7A18), blurRadius: 24, offset: Offset(0, 8))],
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        title: const Text(
          'Expense',
          style: AppBarStyle.titleStyle,
        ),
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _errorMessage != null
              ? ErrorView(message: _errorMessage!, onRetry: reload)
              : RefreshIndicator(
                  color: const Color(0xFFFF7A18),
                  onRefresh: reload,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tabs selector (Expenses & Categories ONLY)
                        _buildTabSelector(),
                        const SizedBox(height: 16),

                        // Switch Tab View
                        if (_selectedTab == 0) _buildExpensesTab() else _buildCategoriesTab(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
    );
  }

  // --- Top Tabs Pill Row ---
  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(child: _tabButton(label: 'Expenses', icon: Icons.receipt_long_rounded, index: 0)),
          if (context.read<AuthProvider>().role != 'Employee') Expanded(child: _tabButton(label: 'Categories', icon: Icons.category_rounded, index: 1)),
        ],
      ),
    );
  }

  Widget _tabButton({required String label, required IconData icon, required int index}) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        setState(() => _selectedTab = index);
      },
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF6B7280)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: EXPENSES TAB
  // ==========================================
  Widget _buildExpensesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage and track branch-wise expenses.',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),

        // 1. Clean Search & Branch / Period Bar (At TOP)
        _buildSearchAndPeriodBar(),
        const SizedBox(height: 20),

        // 2. Summary Metric Cards
        _buildSummaryGrid(),
        const SizedBox(height: 20),

        // 3. Data Table / List
        _buildExpensesTable(),
      ],
    );
  }

  // Summary Metrics Grid / Row
  Widget _buildSummaryGrid() {
    return SizedBox(
      height: 125,
      width: double.infinity,
      child: _metricCard('Total Expenses', _totalExpenses, Icons.account_balance_wallet_rounded,
          const Color(0xFFEDE9FE), AppColors.primary),
    );
  }

  Widget _metricCard(String title, double amount, IconData icon, Color tint, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint),
        boxShadow: const [
          BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount.toStringAsFixed(2),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFilterDropdown<T>({
    required T value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 16,
            color: Color(0xFF64748B),
          ),
          hint: Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF64748B)),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  hint,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          selectedItemBuilder: (context) => items.map((item) {
            final child = item.child;
            return Align(
              alignment: Alignment.centerLeft,
              child: DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 14, color: const Color(0xFF64748B)),
                    const SizedBox(width: 5),
                    Flexible(child: child),
                  ],
                ),
              ),
            );
          }).toList(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF334155),
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Clean Period / Branch / Category Filter & Action Bar
  Widget _buildSearchAndPeriodBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Compact Branch + Category selectors + calendar date filter
          Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildCompactFilterDropdown<int?>(
                  value: _selectedBranchId,
                  hint: 'All Branches',
                  icon: Icons.apartment_rounded,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Branches'),
                    ),
                    ..._branches.map(
                      (b) => DropdownMenuItem<int?>(
                        value: b.id,
                        child: Text(b.name),
                      ),
                    ),
                  ],
                  onChanged: _branchContext.selectedBranchId != null
                      ? null
                      : (val) {
                    setState(() {
                      _selectedBranchId = val;
                      _applyLocalFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                flex: 4,
                child: _buildCompactFilterDropdown<int?>(
                  value: _selectedCategoryId,
                  hint: 'All Categories',
                  icon: Icons.category_rounded,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._categories.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedCategoryId = val;
                      _applyLocalFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 7),
              Tooltip(
                message: _selectedExpenseDate == null
                    ? 'Filter by date'
                    : 'Filtered: ${_selectedExpenseDate!.day.toString().padLeft(2, '0')}-${_selectedExpenseDate!.month.toString().padLeft(2, '0')}-${_selectedExpenseDate!.year}\nTap to change date',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickExpenseFilterDate,
                    onLongPress: _clearExpenseFilterDate,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 40,
                      width: _selectedExpenseDate == null ? 44 : 92,
                      decoration: BoxDecoration(
                        color: _selectedExpenseDate != null ? const Color(0xFFEDE9FE) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedExpenseDate != null ? const Color(0xFFC4B5FD) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: _selectedExpenseDate != null ? const Color(0xFFE85D04) : const Color(0xFF64748B),
                          ),
                          if (_selectedExpenseDate != null) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${_selectedExpenseDate!.day.toString().padLeft(2, '0')} ${_monthShortName(_selectedExpenseDate!.month)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFE85D04),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 2. Period Pills: All, Days (Today), Week, Month — evenly spread, same row
          Row(
            children: _periodOptions.map((period) {
              final isSelected = _selectedPeriod == period;
              final isLast = period == _periodOptions.last;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPeriod = period;
                        _applyLocalFilters();
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE85D04) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE85D04) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          period == 'Days' ? 'Days (Today)' : period,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // 3. Print — single button, opens Export PDF / Export Excel choice
          InkWell(
            onTap: _showPrintOptions,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFC4B5FD)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print_rounded, size: 14, color: Color(0xFFE85D04)),
                  SizedBox(width: 5),
                  Text(
                    'Print',
                    style: TextStyle(
                      color: Color(0xFFE85D04),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 4. + Add Expense — full-width, own row
          InkWell(
            onTap: addExpense,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A18), Color(0xFFE85D04)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF7A18).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 5),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Data Table of Expenses
  Widget _buildExpensesTable() {
    if (_filteredExpenses.isEmpty) {
      return Container(
        width: double.infinity,
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
              child: Icon(Icons.receipt_long_outlined, size: 26, color: Colors.grey[400]),
            ),
            const SizedBox(height: 14),
            const Text(
              'No expenses found',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try changing your search term or period filter',
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Expenses',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(20)),
              child: Text('${_filteredExpenses.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._filteredExpenses.map(_expenseTile),
      ],
    );
  }

  Widget _expenseTile(Expense e) {
    final isCancelled = e.status == 'Cancelled';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _viewExpense(e),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        isCancelled ? Icons.cancel_rounded : Icons.receipt_rounded,
                        color: isCancelled ? AppColors.red : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              e.category,
                              style: const TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(_formatDateDisplay(e.date),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                          const SizedBox(height: 3),
                          Text(
                            e.branch.isNotEmpty ? e.branch : 'No branch',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                          ),
                          if (e.employeeName.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    e.employeeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${e.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            e.status.isNotEmpty ? e.status : 'Active',
                            style: TextStyle(
                              color: isCancelled ? AppColors.red : AppColors.green,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(e.paymentMode.isNotEmpty ? e.paymentMode : '-',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _viewExpense(e),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _editExpense(e),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: CATEGORIES TAB (Image 2 design)
  // ==========================================
  Widget _buildCategoriesTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 750;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildAddCategoryPanel()),
              const SizedBox(width: 18),
              Expanded(flex: 3, child: _buildCategoriesPanel()),
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAddCategoryPanel(),
              const SizedBox(height: 18),
              _buildCategoriesPanel(),
            ],
          );
        }
      },
    );
  }

  // Left Card: Add Category
  Widget _buildAddCategoryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'CATEGORY NAME *',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newCategoryCtrl,
            decoration: InputDecoration(
              hintText: 'e.g. Travel',
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _isAddingCategory ? null : _addCategory,
              icon: _isAddingCategory
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add, size: 18),
              label: const Text(
                'Add Category',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Right Card: Categories List
  Widget _buildCategoriesPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Categories',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(20)),
              child: Text('${_categories.length}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (_categories.isEmpty)
          Container(
            width: double.infinity,
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
                  child: Icon(Icons.category_outlined, size: 26, color: Colors.grey[400]),
                ),
                const SizedBox(height: 14),
                const Text('No categories yet.',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF4B5563))),
              ],
            ),
          )
        else
          ..._categories.map((cat) {
            final isInactive = cat.status == 'Inactive';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isInactive ? const Color(0xFFFEE2E2) : const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.label_rounded,
                        color: isInactive ? AppColors.red : AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: isInactive ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            cat.status,
                            style: TextStyle(
                              color: isInactive ? AppColors.red : AppColors.green,
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toggleCategoryStatus(cat),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFEEF2FF),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      cat.status == 'Active' ? 'Deactivate' : 'Activate',
                      style: const TextStyle(color: Color(0xFFE85D04), fontWeight: FontWeight.w700, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}