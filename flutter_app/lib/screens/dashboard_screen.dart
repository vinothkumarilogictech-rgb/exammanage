import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';
import '../providers/branch_context.dart';
import 'package:provider/provider.dart';
import 'attended_candidates_screen.dart';
import 'branches_screen.dart';
import 'scheduled_candidates_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final api = DioClient();

  late Future<Map<String, dynamic>> future;
  late final BranchContext _branchContext;

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    future = load();
  }

  void _onBranchChanged() {
    if (!mounted) return;
    setState(() {
      future = load();
    });
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    await _branchContext.ensureLoaded();
    final branchId = _branchContext.selectedBranchId;
    final r = await api.dashboard(branchId: branchId);

    final data = Map<String, dynamic>.from(
      r.data['data'] ?? {},
    );

    final stats = DashboardStats.fromMap(
      Map<String, dynamic>.from(
        data['stats'] ?? {},
      ),
    );

    List<Candidate> allCandidates = [];
    try {
      final candRes = await api.candidates(branchId: branchId);
      allCandidates = (candRes.data['data'] as List? ?? [])
          .map((e) => Candidate.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    bool isSameDate(String? candDate, String? targetDate) {
      if (candDate == null || targetDate == null) return false;
      final c = candDate.trim();
      final t = targetDate.trim();
      if (c.isEmpty || t.isEmpty) return false;
      if (c == t) return true;
      if (c.startsWith(t) || t.startsWith(c)) return true;
      final cDt = DateTime.tryParse(c);
      final tDt = DateTime.tryParse(t);
      if (cDt != null && tDt != null) {
        return cDt.year == tDt.year && cDt.month == tDt.month && cDt.day == tDt.day;
      }
      return false;
    }

    final todayCandidatesList = allCandidates.where((c) => isSameDate(c.date, stats.today) && c.status != 'Cancelled').toList();
    final tomorrowCandidatesList = allCandidates.where((c) => isSameDate(c.date, stats.tomorrow) && c.status != 'Cancelled').toList();

    // ==============================================================
    // CURRENT MONTH CANDIDATE SUMMARY
    // ==============================================================
    // Dashboard candidate totals are intentionally month-wise.  The
    // current calendar month is calculated from the device date, so
    // when a new month starts these three counts automatically switch
    // to the new month's candidates without deleting old records.
    final now = DateTime.now();
    bool isCurrentMonth(String? value) {
      if (value == null || value.trim().isEmpty) return false;
      final d = DateTime.tryParse(value.trim());
      return d != null && d.year == now.year && d.month == now.month;
    }

    final currentMonthCandidates = allCandidates
        .where((c) => isCurrentMonth(c.date) && c.status != 'Cancelled')
        .toList();

    final currentMonthTotal = currentMonthCandidates.length;
    final currentMonthAbsent = currentMonthCandidates
        .where((c) => (c.status ?? '').trim().toLowerCase() == 'absent')
        .length;
    final currentMonthRescheduled = currentMonthCandidates
        .where((c) => (c.status ?? '').trim().toLowerCase() == 'rescheduled')
        .length;

    double currentMonthExpense = 0;
    try {
      final expenseRes = await api.expenses(branchId: branchId, status: 'Active');
      final expenses = expenseRes.data['data'] as List? ?? const [];
      for (final raw in expenses) {
        final e = Map<String, dynamic>.from(raw);
        final amount = double.tryParse('${e['amount'] ?? 0}') ?? 0;
        final dateRaw = '${e['date_incurred'] ?? ''}';
        final d = DateTime.tryParse(dateRaw);
        if (d != null && d.year == now.year && d.month == now.month) {
          currentMonthExpense += amount;
        }
      }
    } catch (_) {}

    return {
      'stats': stats,

      'branches': (data['branch_overview'] as List? ?? [])
          .map(
            (e) => DashboardBranch.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),

      'todayExams': (data['today_exams'] as List? ?? [])
          .map(
            (e) => DashboardExam.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),

      'tomorrow': (data['tomorrow_candidates'] as List? ?? [])
          .map(
            (e) => TomorrowBranchCandidates.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),

      'todayCandidates': todayCandidatesList,
      'tomorrowCandidates': tomorrowCandidatesList,
      'allCandidates': allCandidates,
      'currentMonthTotal': currentMonthTotal,
      'currentMonthAbsent': currentMonthAbsent,
      'currentMonthRescheduled': currentMonthRescheduled,
      'currentMonthExpense': currentMonthExpense,
      'selectedBranchId': branchId,
    };
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  String prettyDate(String value) {
    final d = DateTime.tryParse(value);

    if (d == null) {
      return value;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ===========================================================
  // ADD NEW EXAM (Session) DIALOG
  // ===========================================================

  Future<void> _showAddExamDialog() async {
    // Load branches and exam types separately
    List<Map<String, dynamic>> branchesList = [];
    List<Map<String, dynamic>> examTypesList = [];
    try {
      final br = await api.branches();
      branchesList = (br.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final et = await api.examTypes();
      examTypesList = (et.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {}

    if (branchesList.isEmpty || examTypesList.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please create branches and exam types first.',
            ),
          ),
        );
      }
      return;
    }

    int? selectedBranchId = branchesList.first['id'];
    int? selectedExamTypeId = examTypesList.first['id'];
    final dateCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: '09:00');
    final endCtrl = TextEditingController(text: '12:00');
    final feeCtrl = TextEditingController(text: '0');
    final capacityCtrl = TextEditingController(text: '10');

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              24, 16, 24,
              MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
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
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6D28D9), Color(0xFF4C1D95)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.note_add_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('Add New Exam Session', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Branch dropdown
                  _FieldLabel('Branch'),
                  const SizedBox(height: 6),
                  _buildDropdown<int>(
                    value: selectedBranchId,
                    hint: 'Select branch',
                    items: branchesList.map((b) => DropdownMenuItem<int>(
                      value: b['id'],
                      child: Text('${b['branch_name'] ?? ''}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) => setSheetState(() => selectedBranchId = val),
                  ),

                  const SizedBox(height: 14),

                  // Exam Type dropdown
                  _FieldLabel('Exam Type'),
                  const SizedBox(height: 6),
                  _buildDropdown<int>(
                    value: selectedExamTypeId,
                    hint: 'Select exam type',
                    items: examTypesList.map((e) => DropdownMenuItem<int>(
                      value: e['id'],
                      child: Text('${e['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) => setSheetState(() => selectedExamTypeId = val),
                  ),

                  const SizedBox(height: 14),

                  // Date
                  _FieldLabel('Exam Date'),
                  const SizedBox(height: 6),
                  _buildDateField(ctx, dateCtrl),

                  const SizedBox(height: 14),

                  // Time row
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Start Time'),
                      const SizedBox(height: 6),
                      _buildTextField(startCtrl, 'HH:MM'),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('End Time'),
                      const SizedBox(height: 6),
                      _buildTextField(endCtrl, 'HH:MM'),
                    ])),
                  ]),

                  const SizedBox(height: 14),

                  // Fee + Capacity
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Fee'),
                      const SizedBox(height: 6),
                      _buildTextField(feeCtrl, '0.00', keyboardType: TextInputType.number),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Seat Capacity'),
                      const SizedBox(height: 6),
                      _buildTextField(capacityCtrl, '0', keyboardType: TextInputType.number),
                    ])),
                  ]),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity, height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () async {
                        if (dateCtrl.text.isEmpty || selectedBranchId == null || selectedExamTypeId == null) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please fill all required fields')),
                          );
                          return;
                        }
                        try {
                          // Auto-create branch-exam mapping if needed
                          int? mappingId;
                          try {
                            final mapResp = await api.createBranchMapping({
                              'branch_id': selectedBranchId,
                              'exam_type_id': selectedExamTypeId,
                            });
                            mappingId = mapResp.data['data']?['id'];
                          } catch (e) {
                            // Mapping may already exist (409), find existing
                            final existing = await api.branchMappings(branchId: selectedBranchId);
                            final list = existing.data['data'] as List? ?? [];
                            for (final m in list) {
                              if (m['exam_type_id'] == selectedExamTypeId) {
                                mappingId = m['id'];
                                break;
                              }
                            }
                          }
                          if (mappingId == null) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Could not create branch-exam mapping')),
                              );
                            }
                            return;
                          }
                          await api.createSession({
                            'branch_exam_id': mappingId,
                            'exam_date': dateCtrl.text,
                            'start_time': startCtrl.text,
                            'end_time': endCtrl.text,
                            'fee': double.tryParse(feeCtrl.text) ?? 0,
                            'seat_capacity': int.tryParse(capacityCtrl.text) ?? 0,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Exam session created!'), backgroundColor: AppColors.green),
                            );
                            reload();
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      child: const Text('Create Exam Session', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Helper widgets for bottom sheet fields
  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true, value: value, hint: Text(hint),
          items: items, onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint, filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDateField(BuildContext ctx, TextEditingController ctrl, {bool allowPast = false}) {
    return TextField(
      controller: ctrl, readOnly: true,
      decoration: InputDecoration(
        hintText: 'Select date', suffixIcon: const Icon(Icons.calendar_today_rounded),
        filled: true, fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      ),
      onTap: () async {
        final picked = await showDatePicker(
          context: ctx,
          initialDate: DateTime.now(),
          firstDate: allowPast ? DateTime.now().subtract(const Duration(days: 30)) : DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) {
          ctrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        }
      },
    );
  }

  // ===========================================================
  // ADD CANDIDATE DIALOG
  // ===========================================================

  Future<void> _showAddCandidateDialog() async {
    // Load branches and exam types for dropdowns
    List<Map<String, dynamic>> branchesList = [];
    List<Map<String, dynamic>> examTypesList = [];
    try {
      final br = await api.branches();
      branchesList = (br.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final et = await api.examTypes();
      examTypesList = (et.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {}

    int? selectedBranchId =
        branchesList.isNotEmpty
            ? branchesList.first['id']
            : null;
    int? selectedExamTypeId =
        examTypesList.isNotEmpty
            ? examTypesList.first['id']
            : null;

    // Candidate status can also be selected while adding the candidate.
    String selectedStatus = 'Registered';

    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final regNumCtrl = TextEditingController();
    final dateCtrl = TextEditingController();

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(28),
              ),
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
                  // Drag handle
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

                  // Title
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF059669),
                              Color(0xFF047857),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Add Candidate',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Name
                  _FieldLabel('Full Name *'),
                  const SizedBox(height: 6),
                  _StyledTextField(
                    controller: nameCtrl,
                    hint: 'Enter candidate name',
                    icon: Icons.person_outline_rounded,
                  ),

                  const SizedBox(height: 14),

                  // Register Number
                  _FieldLabel('Register Number'),
                  const SizedBox(height: 6),
                  _StyledTextField(
                    controller: regNumCtrl,
                    hint: 'Enter register number',
                    icon: Icons.badge_outlined,
                  ),

                  const SizedBox(height: 14),

                  // Branch dropdown
                  _FieldLabel('Branch'),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: selectedBranchId,
                        hint: const Text('Select branch'),
                        items: branchesList.map((b) {
                          return DropdownMenuItem<int>(
                            value: b['id'],
                            child: Text(
                              '${b['branch_name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() {
                            selectedBranchId = val;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Exam Type dropdown
                  _FieldLabel('Exam Type'),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE5E7EB),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: selectedExamTypeId,
                        hint: const Text('Select exam type'),
                        items: examTypesList.map((e) {
                          return DropdownMenuItem<int>(
                            value: e['id'],
                            child: Text(
                              '${e['name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() {
                            selectedExamTypeId = val;
                          });
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Candidate Status
                  _FieldLabel('Status'),
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
                        value: selectedStatus,
                        hint: const Text('Select status'),
                        items: const [
                          DropdownMenuItem<String>(
                            value: 'Registered',
                            child: Row(children: [
                              Icon(Icons.how_to_reg_rounded, size: 18, color: Color(0xFF2563EB)),
                              SizedBox(width: 8),
                              Expanded(child: Text('Registered')),
                            ]),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Absent',
                            child: Row(children: [
                              Icon(Icons.person_off_rounded, size: 18, color: Color(0xFFEA580C)),
                              SizedBox(width: 8),
                              Expanded(child: Text('Absent')),
                            ]),
                          ),
                          DropdownMenuItem<String>(
                            value: 'Rescheduled',
                            child: Row(children: [
                              Icon(Icons.event_repeat_rounded, size: 18, color: Color(0xFF7C3AED)),
                              SizedBox(width: 8),
                              Expanded(child: Text('Rescheduled')),
                            ]),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setSheetState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Exam Date
                  _FieldLabel('Exam Date'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: 'Select date',
                      suffixIcon: const Icon(
                        Icons.calendar_today_rounded,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF9FAFB),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFFE5E7EB),
                        ),
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        // Candidate dates are intentionally unrestricted:
                        // past, today, and future dates are all allowed.
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        dateCtrl.text =
                            '${picked.year}-'
                            '${picked.month.toString().padLeft(2, '0')}-'
                            '${picked.day.toString().padLeft(2, '0')}';
                      }
                    },
                  ),

                  const SizedBox(height: 24),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF059669),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Candidate name is required',
                              ),
                            ),
                          );
                          return;
                        }
                        try {
                          await api.createCandidate({
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'register_number':
                                regNumCtrl.text.trim(),
                            'branch_id': selectedBranchId,
                            'exam_type_id':
                                selectedExamTypeId,
                            'status': selectedStatus,
                            'exam_date': dateCtrl.text,
                          });
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Candidate added!',
                                ),
                                backgroundColor:
                                    AppColors.green,
                              ),
                            );
                            reload();
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text(
                        'Add Candidate',
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
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODAL: ALL BRANCHES
  // ─────────────────────────────────────────────────────────────────────────
  void _showBranchesModal() async {
    try {
      final res = await api.branches();
      final list = (res.data['data'] as List? ?? []).map((e) => Branch.fromMap(e)).toList();
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _ModalHandle(),
              _ModalHeader(
                icon: Icons.business_rounded,
                iconColor: AppColors.primary,
                iconBg: const Color(0xFFEDE9FE),
                title: 'All Branches',
                subtitle: '${list.length} branches registered',
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? const Center(child: Text('No branches available'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final b = list[i];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: const Color(0xFFEDE9FE),
                                  child: Text(
                                    b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      if (b.region.isNotEmpty)
                                        Text(b.region, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      if (b.address.isNotEmpty)
                                        Text(b.address, style: TextStyle(color: Colors.grey[500], fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(12)),
                                  child: Text(b.status, style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading branches: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODAL: FILTERED CANDIDATES (today / tomorrow / all)
  // ─────────────────────────────────────────────────────────────────────────
  void _showCandidatesModal(String title, String? filterDate) async {
    try {
      final res = await api.candidates();
      List<Candidate> list = (res.data['data'] as List? ?? []).map((e) => Candidate.fromMap(e)).toList();
      if (filterDate != null && filterDate.isNotEmpty) {
        list = list.where((c) => c.date == filterDate).toList();
      }
      if (!mounted) return;

      final Color accentColor = filterDate == null
          ? AppColors.blue
          : filterDate.isNotEmpty
              ? AppColors.green
              : AppColors.primary;
      final Color accentBg = filterDate == null
          ? const Color(0xFFDBEAFE)
          : filterDate.isNotEmpty
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFEDE9FE);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _ModalHandle(),
              _ModalHeader(
                icon: Icons.people_alt_rounded,
                iconColor: accentColor,
                iconBg: accentBg,
                title: title,
                subtitle: list.isEmpty ? 'No candidates' : '${list.length} candidate${list.length == 1 ? '' : 's'}',
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No candidates for $title', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        itemBuilder: (c, i) {
                          final item = list[i];
                          final statusColor = item.status.toLowerCase().contains('pass')
                              ? AppColors.green
                              : item.status.toLowerCase().contains('fail')
                                  ? const Color(0xFFE11D48)
                                  : AppColors.primary;
                          final statusBg = item.status.toLowerCase().contains('pass')
                              ? const Color(0xFFDCFCE7)
                              : item.status.toLowerCase().contains('fail')
                                  ? const Color(0xFFFFE4E6)
                                  : const Color(0xFFEDE9FE);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: accentBg,
                                  child: Text(
                                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                                    style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text('${item.examType} • ${item.branch}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      if (item.date.isNotEmpty)
                                        Text('📅 ${item.date}', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                                      child: Text(item.status.isEmpty ? 'Scheduled' : item.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    if (item.registerNumber.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('#${item.registerNumber}', style: TextStyle(color: Colors.grey[400], fontSize: 10)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading candidates: $e')));
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODAL: TODAY'S EXAMS (section heading tap)
  // ─────────────────────────────────────────────────────────────────────────
  void _showTodaysExamsModal(List<DashboardExam> exams) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _ModalHandle(),
            _ModalHeader(
              icon: Icons.calendar_month_rounded,
              iconColor: AppColors.primary,
              iconBg: const Color(0xFFEDE9FE),
              title: "Today's Exams",
              subtitle: exams.isEmpty ? 'No exams today' : '${exams.length} exam session${exams.length == 1 ? '' : 's'}',
            ),
            const Divider(height: 1),
            Expanded(
              child: exams.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text("No exams scheduled for today", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: exams.length,
                      itemBuilder: (c, i) {
                        final e = exams[i];
                        Color statusColor;
                        Color statusBg;
                        IconData statusIcon;
                        switch (e.status.toLowerCase()) {
                          case 'completed':
                            statusColor = AppColors.green;
                            statusBg = const Color(0xFFDCFCE7);
                            statusIcon = Icons.check_circle_rounded;
                            break;
                          case 'in_progress':
                          case 'ongoing':
                            statusColor = const Color(0xFFD97706);
                            statusBg = const Color(0xFFFEF3C7);
                            statusIcon = Icons.play_circle_rounded;
                            break;
                          default:
                            statusColor = AppColors.primary;
                            statusBg = const Color(0xFFEDE9FE);
                            statusIcon = Icons.schedule_rounded;
                        }
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 22),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.examTypeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        Text(e.branchName, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon, size: 12, color: statusColor),
                                        const SizedBox(width: 4),
                                        Text(e.status.isEmpty ? 'Scheduled' : e.status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: Color(0xFFF3F4F6)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _InfoChip(icon: Icons.access_time_rounded, label: '${e.startTime} – ${e.endTime}'),
                                  const SizedBox(width: 8),
                                  _InfoChip(icon: Icons.people_rounded, label: '${e.candidateCount} candidate${e.candidateCount == 1 ? '' : 's'}'),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MODAL: TOMORROW'S CANDIDATES (section heading tap)
  // ─────────────────────────────────────────────────────────────────────────
  void _showTomorrowCandidatesModal(List<TomorrowBranchCandidates> tomorrow, DashboardStats stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            _ModalHandle(),
            _ModalHeader(
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFFE11D48),
              iconBg: const Color(0xFFFFE4E6),
              title: "Tomorrow's Candidates",
              subtitle: prettyDate(stats.tomorrow),
            ),
            const Divider(height: 1),
            Expanded(
              child: tomorrow.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text("No candidates scheduled for tomorrow", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: tomorrow.length,
                            itemBuilder: (c, i) {
                              final item = tomorrow[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE5E7EB)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 38, height: 38,
                                            decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(12)),
                                            child: const Icon(Icons.location_on_rounded, color: Color(0xFFE11D48), size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(item.branchName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(20)),
                                            child: Text('${item.candidateCount} candidate${item.candidateCount == 1 ? '' : 's'}',
                                                style: const TextStyle(color: Color(0xFFE11D48), fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                                      child: Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: item.examBreakdown.entries.map((entry) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(color: const Color(0xFFF0E9FF), borderRadius: BorderRadius.circular(20)),
                                            child: Text('${entry.key}: ${entry.value}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        // Total footer
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0E9FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Total Tomorrow's Candidates", style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                              Text('${stats.tomorrowCandidates}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchSelector() {
    final branchContext = context.watch<BranchContext>();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: branchContext.selectedBranchId,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          hint: const Text('Select Branch'),
          items: [
...branchContext.branches.map(
              (b) => DropdownMenuItem<int?>(
                value: b.id,
                child: Row(
                  children: [
                    const Icon(Icons.business_rounded, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (id) => branchContext.selectBranch(id),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FC),

      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,

        title: const Text(
          'Exam Dashboard',
          style: AppBarStyle.titleStyle,
        ),

        actions: [
          IconButton(
            onPressed: reload,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: FutureBuilder<Map<String, dynamic>>(
        future: future,

        builder: (context, snapshot) {
          if (snapshot.connectionState !=
              ConnectionState.done) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: reload,
            );
          }

          final data = snapshot.requireData;

          final stats =
              data['stats'] as DashboardStats;

          final currentMonthTotal =
              data['currentMonthTotal'] as int? ?? 0;
          final currentMonthAbsent =
              data['currentMonthAbsent'] as int? ?? 0;
          final currentMonthRescheduled =
              data['currentMonthRescheduled'] as int? ?? 0;
          final currentMonthExpense =
              (data['currentMonthExpense'] as num?)?.toDouble() ?? 0.0;

          /*
           * IMPORTANT:
           *
           * Branch priority:
           *
           * 1. Branches having today's exams first
           * 2. Among those branches, more candidates first
           * 3. Branches having no exams come last
           * 4. No-exam branches are sorted alphabetically
           */
          final branches = List<DashboardBranch>.from(
            data['branches'] as List<DashboardBranch>,
          ).where((b) => b.todayCandidates > 0 || b.tomorrowCandidates > 0 || b.todayExams > 0).toList();

          branches.sort(
            (a, b) {
              final aHasExam =
                  a.todayExams > 0;

              final bHasExam =
                  b.todayExams > 0;

              // -----------------------------------------
              // 1. Exam branches first
              // -----------------------------------------

              if (aHasExam && !bHasExam) {
                return -1;
              }

              if (!aHasExam && bHasExam) {
                return 1;
              }

              // -----------------------------------------
              // 2. If both have exams,
              //    more candidates first
              // -----------------------------------------

              if (aHasExam && bHasExam) {
                final candidateCompare =
                    b.todayCandidates.compareTo(
                  a.todayCandidates,
                );

                if (candidateCompare != 0) {
                  return candidateCompare;
                }

                // If same candidate count,
                // more exams first.
                final examCompare =
                    b.todayExams.compareTo(
                  a.todayExams,
                );

                if (examCompare != 0) {
                  return examCompare;
                }
              }

              // -----------------------------------------
              // 3. No-exam branches at bottom
              // 4. Alphabetical order
              // -----------------------------------------

              return a.name
                  .toLowerCase()
                  .compareTo(
                    b.name.toLowerCase(),
                  );
            },
          );

          final todayCandidates =
              data['todayCandidates'] as List<Candidate>? ?? [];

          final tomorrowCandidates =
              data['tomorrowCandidates'] as List<Candidate>? ?? [];

          return RefreshIndicator(
            color: AppColors.primary,

            onRefresh: () async {
              reload();
            },

            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                24,
              ),

              children: [

                // =================================================
                // GLOBAL BRANCH SELECTOR
                // =================================================
                _buildBranchSelector(),

                const SizedBox(height: 16),

                // =================================================
                // KPI CARDS
                // =================================================

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.45,
                  children: [
                    // ---------------------------------------------
                    // TOTAL BRANCHES
                    // ---------------------------------------------

                    _KpiCard(
                      title: 'Total Branches',
                      value: '${stats.totalBranches}',
                      icon: Icons.business_rounded,
                      tint: const Color(0xFFEDE9FE),
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BranchesScreen(),
                          ),
                        );
                      },
                    ),

                    // ---------------------------------------------
                    // TODAY'S CANDIDATES
                    // ---------------------------------------------

                    _KpiCard(
                      title: "Today's Candidates",
                      value: '${stats.todayCandidates}',
                      icon: Icons.groups_rounded,
                      tint: const Color(0xFFDCFCE7),
                      iconColor: AppColors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScheduledCandidatesScreen(
                              title: "Today's Candidates",
                              date: stats.today,
                              isToday: true,
                            ),
                          ),
                        );
                      },
                    ),

                    // ---------------------------------------------
                    // TOMORROW'S CANDIDATES
                    // ---------------------------------------------

                    _KpiCard(
                      title: "Tomorrow's Candidates",
                      value: '${stats.tomorrowCandidates}',
                      icon: Icons.event_available_rounded,
                      tint: const Color(0xFFFFE4E6),
                      iconColor: const Color(0xFFE11D48),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ScheduledCandidatesScreen(
                              title: "Tomorrow's Candidates",
                              date: stats.tomorrow,
                              isToday: false,
                            ),
                          ),
                        );
                      },
                    ),

                    // ---------------------------------------------
                    // TOTAL ATTENDED CANDIDATES
                    // ---------------------------------------------

                    _KpiCard(
                      title: 'Total Candidates',
                      value: '$currentMonthTotal',
                      icon: Icons.verified_rounded,
                      tint: const Color(0xFFDBEAFE),
                      iconColor: AppColors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendedCandidatesScreen(),
                          ),
                        );
                      },
                    ),

                    // ---------------------------------------------
                    // CURRENT MONTH ABSENT
                    // ---------------------------------------------
                    _KpiCard(
                      title: 'Total Absent',
                      value: '$currentMonthAbsent',
                      icon: Icons.person_off_rounded,
                      tint: const Color(0xFFFFEDD5),
                      iconColor: const Color(0xFFEA580C),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendedCandidatesScreen(
                              initialFilter: 'Today',
                              initialStatus: 'Absent',
                            ),
                          ),
                        );
                      },
                    ),

                    // ---------------------------------------------
                    // CURRENT MONTH RESCHEDULED
                    // ---------------------------------------------
                    _KpiCard(
                      title: 'Total Rescheduled',
                      value: '$currentMonthRescheduled',
                      icon: Icons.event_repeat_rounded,
                      tint: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AttendedCandidatesScreen(
                              initialFilter: 'Today',
                              initialStatus: 'Rescheduled',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // =================================================
                // TOTAL EXPENSE PER MONTH
                // =================================================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.05),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3E8FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Expense Per Month',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${currentMonthExpense.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =================================================
                // BRANCH OVERVIEW
                // =================================================

                _SectionCard(
                  title: 'Branch Overview',
                  icon: Icons.location_on_rounded,
                  action: 'View All',
                  child: branches.isEmpty
                      ? const _EmptyText(
                          'No active exam branches for today or tomorrow',
                        )
                      : Column(
                          children: branches.map(
                            (branch) {
                              return _BranchRow(
                                branch: branch,
                              );
                            },
                          ).toList(),
                        ),
                ),

                const SizedBox(height: 16),

                // =================================================
                // TODAY'S CANDIDATES
                // =================================================

                _SectionCard(
                  title: "Today's Candidates",
                  icon: Icons.groups_rounded,
                  action: 'View All',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduledCandidatesScreen(
                          title: "Today's Candidates",
                          date: stats.today,
                          isToday: true,
                        ),
                      ),
                    );
                  },
                  child: todayCandidates.isEmpty
                      ? const _EmptyText('No candidates scheduled for today')
                      : Column(
                          children: todayCandidates
                              .map((c) => _CandidateRow(candidate: c))
                              .toList(),
                        ),
                ),

                const SizedBox(height: 16),

                // =================================================
                // TOMORROW'S CANDIDATES
                // =================================================

                _SectionCard(
                  title: "Tomorrow's Candidates",
                  icon: Icons.event_available_rounded,
                  action: 'View All',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduledCandidatesScreen(
                          title: "Tomorrow's Candidates",
                          date: stats.tomorrow,
                          isToday: false,
                        ),
                      ),
                    );
                  },
                  trailing: Text(
                    prettyDate(stats.tomorrow),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  child: tomorrowCandidates.isEmpty
                      ? const _EmptyText('No candidates scheduled for tomorrow')
                      : Column(
                          children: [
                            ...tomorrowCandidates.map((c) => _CandidateRow(candidate: c)),

                            const SizedBox(height: 8),

                            // -----------------------------------
                            // TOTAL
                            // -----------------------------------

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0E9FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "Total Tomorrow's Candidates",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    '${tomorrowCandidates.length > stats.tomorrowCandidates ? tomorrowCandidates.length : stats.tomorrowCandidates}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// FIELD LABEL (for dialogs)
// ================================================================

// ignore: non_constant_identifier_names
Widget _FieldLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: Color(0xFF4B5563),
    ),
  );
}

// ================================================================
// STYLED TEXT FIELD (for dialogs)
// ================================================================

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;

  const _StyledTextField({
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20)
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFFE5E7EB),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}

// ================================================================
// QUICK ACTION CARD
// ================================================================

class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: gradientColors.first
                    .withOpacity(.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.20),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// KPI CARD
// ================================================================

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;

  final IconData icon;

  final Color tint;
  final Color iconColor;

  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius:
          BorderRadius.circular(20),

      onTap: onTap,

      child: Container(
        padding:
            const EdgeInsets.all(14),

        decoration:
            BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(20),

          border: Border.all(
            color: tint,
          ),

          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),

              blurRadius: 12,

              offset:
                  Offset(0, 4),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [
            Container(
              width: 36,
              height: 36,

              decoration:
                  BoxDecoration(
                color: tint,

                borderRadius:
                    BorderRadius.circular(11),
              ),

              child: Icon(
                icon,

                color:
                    iconColor,

                size: 19,
              ),
            ),

            const Spacer(),

            Text(
              title,

              maxLines: 1,

              overflow:
                  TextOverflow.ellipsis,

              style:
                  const TextStyle(
                fontSize: 11.5,

                fontWeight:
                    FontWeight.w700,

                color:
                    Color(0xFF4B5563),
              ),
            ),

            const SizedBox(
              height: 2,
            ),

            Text(
              value,

              style:
                  const TextStyle(
                fontSize: 22,

                fontWeight:
                    FontWeight.w900,

                color:
                    Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SECTION CARD
// ================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? action;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final header = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          if (trailing != null) trailing!,
          if (action != null || onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: onTap != null ? AppColors.primary : Colors.grey[400],
            ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          header,
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}


void _showDashboardBranchDetails(BuildContext context, DashboardBranch b) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(ctx).padding.bottom + 24,
      ),
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      b.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: b.status.toLowerCase() == 'active'
                            ? const Color(0xFFDCFCE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        b.status,
                        style: TextStyle(
                          color: b.status.toLowerCase() == 'active'
                              ? AppColors.green
                              : const Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'TODAY\'S ACTIVITY',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          _detailRow(
            Icons.event_available_rounded,
            'Today\'s Exams',
            '${b.todayExams} sessions scheduled',
          ),
          const SizedBox(height: 12),
          _detailRow(
            Icons.groups_rounded,
            'Today\'s Candidates',
            '${b.todayCandidates} candidates attending',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Close'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _detailRow(IconData icon, String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ================================================================
// BRANCH ROW
// ================================================================

class _BranchRow extends StatelessWidget {
  final DashboardBranch branch;

  const _BranchRow({
    required this.branch,
  });

  @override
  Widget build(BuildContext context) {
    final hasExams = branch.todayCandidates > 0 || branch.tomorrowCandidates > 0 || branch.todayExams > 0;

    return InkWell(
      onTap: () => _showDashboardBranchDetails(context, branch),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),

      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),

      decoration:
          BoxDecoration(
        color: hasExams
            ? const Color(0xFFFAF8FF)
            : const Color(0xFFF9FAFB),

        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          // ---------------------------------------------
          // BRANCH ICON
          // ---------------------------------------------

          Container(
            width: 42,
            height: 42,

            decoration:
                BoxDecoration(
              color: hasExams
                  ? const Color(
                      0xFFEDE9FE,
                    )
                  : const Color(
                      0xFFF3F4F6,
                    ),

              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),

            child: Icon(
              Icons.business_rounded,

              color: hasExams
                  ? AppColors.primary
                  : const Color(
                      0xFF9CA3AF,
                    ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          // ---------------------------------------------
          // BRANCH DETAILS
          // ---------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  branch.name,

                  maxLines: 1,

                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,

                    fontSize: 14.5,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  branch.todayCandidates > 0 && branch.tomorrowCandidates > 0
                      ? '${branch.todayCandidates} candidates today • ${branch.tomorrowCandidates} tomorrow'
                      : branch.todayCandidates > 0
                          ? '${branch.todayCandidates} ${branch.todayCandidates == 1 ? "candidate" : "candidates"} today'
                          : branch.tomorrowCandidates > 0
                              ? '${branch.tomorrowCandidates} ${branch.tomorrowCandidates == 1 ? "candidate" : "candidates"} tomorrow'
                              : '${branch.todayExams} exams scheduled',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 6,
          ),

          // ---------------------------------------------
          // STATUS
          // ---------------------------------------------

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              branch.totalScheduled > 0
                  ? '${branch.totalScheduled} Candidate${branch.totalScheduled > 1 ? "s" : ""}'
                  : 'Active',
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

// ================================================================
// TODAY'S EXAM ROW
// ================================================================

class _ExamRow extends StatelessWidget {
  final DashboardExam exam;

  const _ExamRow({
    required this.exam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),

      padding:
          const EdgeInsets.all(11),

      decoration:
          BoxDecoration(
        color:
            const Color(0xFFFAF8FF),

        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Row(
        children: [
          Container(
            width: 5,
            height: 56,

            decoration:
                BoxDecoration(
              color:
                  AppColors.primary,

              borderRadius:
                  BorderRadius.circular(
                8,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  exam.examTypeName,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w900,

                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  exam.branchName,

                  style:
                      const TextStyle(
                    color:
                        Color(0xFF4B5563),

                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  '${exam.startTime} • '
                  '${exam.candidateCount} candidates',

                  style:
                      const TextStyle(
                    color:
                        Color(0xFF6B7280),

                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 9,
              vertical: 6,
            ),

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFFDCFCE7,
              ),

              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),

            child: const Text(
              'Scheduled',

              style:
                  TextStyle(
                color:
                    AppColors.green,

                fontSize: 10.5,

                fontWeight:
                    FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// TOMORROW'S CANDIDATES ROW
// ================================================================

class _TomorrowRow extends StatelessWidget {
  final TomorrowBranchCandidates item;

  const _TomorrowRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 2,
      ),

      leading:
          const CircleAvatar(
        backgroundColor:
            Color(0xFFEDE9FE),

        child: Icon(
          Icons.location_on_rounded,

          color:
              AppColors.primary,

          size: 19,
        ),
      ),

      title: Text(
        item.branchName,

        style:
            const TextStyle(
          fontWeight:
              FontWeight.w800,
        ),
      ),

      subtitle: Text(
        item.examBreakdown.entries
            .map(
              (entry) =>
                  '${entry.key}: ${entry.value}',
            )
            .join(' • '),

        style:
            const TextStyle(
          fontSize: 11.5,
        ),
      ),

      trailing:
          Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 7,
        ),

        decoration:
            BoxDecoration(
          color:
              const Color(0xFFF0E9FF),

          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),

        child: Text(
          '${item.candidateCount}',

          style:
              const TextStyle(
            color:
                AppColors.primary,

            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// CANDIDATE ROW (FOR DASHBOARD SECTIONS)
// ================================================================

class _CandidateRow extends StatelessWidget {
  final Candidate candidate;

  const _CandidateRow({required this.candidate});

  // Color generator based on name
  Color _avatarBg(String name) {
    final colors = [
      const Color(0xFFEDE9FE),
      const Color(0xFFDCFCE7),
      const Color(0xFFDBEAFE),
      const Color(0xFFFFE4E6),
      const Color(0xFFFEF3C7),
      const Color(0xFFF3E8FF),
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  Color _avatarText(String name) {
    final colors = [
      AppColors.primary,
      AppColors.green,
      AppColors.blue,
      const Color(0xFFE11D48),
      const Color(0xFFD97706),
      const Color(0xFF9333EA),
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : '?';

    // Status colors
    Color statusColor;
    Color statusBg;
    final s = candidate.status.toLowerCase();
    if (s.contains('pass') || s == 'completed') {
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFDCFCE7);
    } else if (s.contains('fail') || s == 'cancelled') {
      statusColor = const Color(0xFFE11D48);
      statusBg = const Color(0xFFFFE4E6);
    } else if (s == 'in progress' || s == 'in_progress' || s == 'ongoing') {
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFEF3C7);
    } else if (s == 'scheduled') {
      statusColor = const Color(0xFF7C3AED);
      statusBg = const Color(0xFFEDE9FE);
    } else if (s == 'no show' || s == 'no_show' || s == 'absent') {
      statusColor = const Color(0xFFEA580C);
      statusBg = const Color(0xFFFFEDD5);
    } else {
      statusColor = const Color(0xFF2563EB);
      statusBg = const Color(0xFFDBEAFE);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _avatarBg(candidate.name),
            child: Text(
              initial,
              style: TextStyle(
                color: _avatarText(candidate.name),
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  candidate.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${candidate.registerNumber.isNotEmpty ? '#${candidate.registerNumber}' : 'ID: ${candidate.id}'} • ${candidate.examType} (${candidate.branch})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              candidate.status.isEmpty ? 'Registered' : candidate.status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// EMPTY TEXT
// ================================================================

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(
    this.text,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 22,
      ),

      child: Center(
        child: Text(
          text,

          textAlign:
              TextAlign.center,

          style:
              const TextStyle(
            color:
                Color(0xFF6B7280),

            fontSize: 13,

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MODAL HANDLE (drag indicator)
// ================================================================

class _ModalHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// MODAL HEADER
// ================================================================

class _ModalHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _ModalHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// INFO CHIP (small label with icon)
// ================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}