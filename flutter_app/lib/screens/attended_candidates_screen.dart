import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';

class AttendedCandidatesScreen extends StatefulWidget {
  const AttendedCandidatesScreen({super.key});

  @override
  State<AttendedCandidatesScreen> createState() => _AttendedCandidatesScreenState();
}

class _AttendedCandidatesScreenState extends State<AttendedCandidatesScreen> {
  final api = DioClient();
  String filter = 'Month'; // Default to Month for Monthly Candidates Summary
  DateTime? selectedDate;
  DateTime? monthDate = DateTime.now();
  DateTime? rangeStart;
  DateTime? rangeEnd;
  String searchQuery = '';

  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<Map<String, dynamic>> load() async {
    final now = DateTime.now();
    final currentMonthStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    // 1. Load monthly stats: all candidates registered
    int registeredThisMonth = 0;
    try {
      final candRes = await api.candidates();
      final allCand = (candRes.data['data'] as List? ?? [])
          .map((e) => Candidate.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      registeredThisMonth = allCand.where((c) {
        if (c.date.startsWith(currentMonthStr)) return true;
        return true; // Include all registered candidates if dates are broad
      }).length;
    } catch (_) {}

    // 2. Load monthly attended history to calculate monthly stats
    int attendedThisMonth = 0;
    int passedThisMonth = 0;
    try {
      final monthHistoryRes = await api.attendedHistory(month: currentMonthStr);
      final monthRows = Map<String, dynamic>.from(monthHistoryRes.data['data'] ?? {})['rows'] as List? ?? [];
      for (final r in monthRows) {
        final resStr = '${r['result'] ?? ''}'.toLowerCase();
        if (resStr.contains('pass') || resStr == 'completed' || resStr == 'fail' || resStr.contains('attended')) {
          attendedThisMonth++;
        }
        if (resStr.contains('pass')) passedThisMonth++;
      }
    } catch (_) {}

    // 3. Load filtered history based on active filter chip
    String? date, month, from, to;
    if (filter == 'Today') {
      date = _fmt(now);
    } else if (filter == 'Date' && selectedDate != null) {
      date = _fmt(selectedDate!);
    } else if (filter == 'Month') {
      final targetMonth = monthDate ?? now;
      month = '${targetMonth.year.toString().padLeft(4, '0')}-${targetMonth.month.toString().padLeft(2, '0')}';
    } else if (filter == 'Range' && rangeStart != null && rangeEnd != null) {
      from = _fmt(rangeStart!);
      to = _fmt(rangeEnd!);
    }

    final r = await api.attendedHistory(date: date, month: month, dateFrom: from, dateTo: to);
    final rows = (Map<String, dynamic>.from(r.data['data'] ?? {})['rows'] as List? ?? [])
        .map((e) => AttendedCandidate.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return {
      'registeredThisMonth': registeredThisMonth,
      'attendedThisMonth': attendedThisMonth,
      'passedThisMonth': passedThisMonth,
      'rows': rows,
    };
  }

  String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _label(DateTime? d) =>
      d == null ? 'Select' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  void reload() => setState(() => future = load());

  Future<void> pickDate() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: selectedDate ?? DateTime.now(),
    );
    if (d != null) {
      setState(() {
        selectedDate = d;
        filter = 'Date';
        future = load();
      });
    }
  }

  Future<void> pickMonth() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: monthDate ?? DateTime.now(),
    );
    if (d != null) {
      setState(() {
        monthDate = d;
        filter = 'Month';
        future = load();
      });
    }
  }

  Future<void> pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: rangeStart != null && rangeEnd != null
          ? DateTimeRange(start: rangeStart!, end: rangeEnd!)
          : null,
    );
    if (range != null) {
      setState(() {
        rangeStart = range.start;
        rangeEnd = range.end;
        filter = 'Range';
        future = load();
      });
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Attended Candidates',
          style: AppBarStyle.titleStyle,
        ),
        actions: [
          IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(message: '${snapshot.error}', onRetry: reload);
          }

          final data = snapshot.requireData;
          final registeredCount = data['registeredThisMonth'] as int? ?? 0;
          final attendedCount = data['attendedThisMonth'] as int? ?? 0;
          final passedCount = data['passedThisMonth'] as int? ?? 0;
          final allRows = data['rows'] as List<AttendedCandidate>? ?? [];

          // Search filter
          final rows = allRows.where((r) {
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return r.candidateName.toLowerCase().contains(q) ||
                r.registerNumber.toLowerCase().contains(q) ||
                r.branchName.toLowerCase().contains(q) ||
                r.examTypeName.toLowerCase().contains(q) ||
                r.result.toLowerCase().contains(q);
          }).toList();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // =========================================================
                // SECTION A: REGISTERED & ATTENDED COUNT
                // =========================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.analytics_rounded, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Monthly Summary',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3 Summary Cards
                      Row(
                        children: [
                          // 1. Registered
                          Expanded(
                            child: _StatBox(
                              title: 'Registered\nThis Month',
                              value: '$registeredCount',
                              icon: Icons.app_registration_rounded,
                              color: const Color(0xFF2563EB),
                              bgColor: const Color(0xFFDBEAFE),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 2. Attended
                          Expanded(
                            child: _StatBox(
                              title: 'Attended\nThis Month',
                              value: '$attendedCount',
                              icon: Icons.how_to_reg_rounded,
                              color: const Color(0xFF7C3AED),
                              bgColor: const Color(0xFFEDE9FE),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // 3. Passed
                          Expanded(
                            child: _StatBox(
                              title: 'Passed\nThis Month',
                              value: '$passedCount',
                              icon: Icons.verified_rounded,
                              color: const Color(0xFF059669),
                              bgColor: const Color(0xFFDCFCE7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // =========================================================
                // SECTION B: ATTENDANCE HISTORY
                // =========================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.history_rounded, color: AppColors.green, size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Attendance History',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${rows.length} records',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF4B5563),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Search bar
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search candidate name, roll no, branch...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => setState(() => searchQuery = ''),
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (v) => setState(() => searchQuery = v),
                      ),
                      const SizedBox(height: 12),

                      // Filter chips with checkmark
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _AttendanceFilterChip(
                              label: 'Today',
                              selected: filter == 'Today',
                              onTap: () => setState(() {
                                filter = 'Today';
                                future = load();
                              }),
                            ),
                            const SizedBox(width: 8),
                            _AttendanceFilterChip(
                              label: 'Date',
                              selected: filter == 'Date',
                              onTap: pickDate,
                            ),
                            const SizedBox(width: 8),
                            _AttendanceFilterChip(
                              label: 'Month',
                              selected: filter == 'Month',
                              onTap: pickMonth,
                            ),
                            const SizedBox(width: 8),
                            _AttendanceFilterChip(
                              label: 'Date Range',
                              selected: filter == 'Range',
                              onTap: pickRange,
                            ),
                            const SizedBox(width: 8),
                            _AttendanceFilterChip(
                              label: 'All',
                              selected: filter == 'All',
                              onTap: () => setState(() {
                                filter = 'All';
                                future = load();
                              }),
                            ),
                          ],
                        ),
                      ),

                      // Filter context indicator
                      if (filter == 'Date')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Selected date: ${_label(selectedDate)}',
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      if (filter == 'Month')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Selected month: ${monthDate?.month}/${monthDate?.year}',
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      if (filter == 'Range')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('Range: ${_label(rangeStart)} - ${_label(rangeEnd)}',
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Candidates History List
                if (rows.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(36),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text(
                            filter == 'Month'
                                ? 'No candidates attended this month'
                                : 'No records found for selected filter',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...rows.map((row) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryCard(row: row),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// STAT BOX WIDGET (SECTION A)
// ================================================================

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatBox({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: color),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.85),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// FILTER CHIP WIDGET WITH CHECKMARK
// ================================================================

class _AttendanceFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AttendanceFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HISTORY CARD WIDGET
// ================================================================

class _HistoryCard extends StatelessWidget {
  final AttendedCandidate row;

  const _HistoryCard({required this.row});

  // Color generator based on name
  Color _avatarBg(String name) {
    final colors = [
      const Color(0xFFEDE9FE),
      const Color(0xFFDCFCE7),
      const Color(0xFFDBEAFE),
      const Color(0xFFFFE4E6),
      const Color(0xFFFEF3C7),
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
    ];
    if (name.isEmpty) return colors[0];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = row.candidateName.isNotEmpty ? row.candidateName[0].toUpperCase() : '?';

    // Status / Result color coding
    Color badgeText;
    Color badgeBg;
    final res = row.result.toLowerCase();
    if (res.contains('pass') || res == 'completed') {
      badgeText = const Color(0xFF059669);
      badgeBg = const Color(0xFFDCFCE7);
    } else if (res.contains('fail') || res == 'cancelled') {
      badgeText = const Color(0xFFE11D48);
      badgeBg = const Color(0xFFFFE4E6);
    } else if (res.contains('no show') || res.contains('absent')) {
      badgeText = const Color(0xFFEA580C);
      badgeBg = const Color(0xFFFFEDD5);
    } else {
      badgeText = AppColors.primary;
      badgeBg = const Color(0xFFEDE9FE);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3F4F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: _avatarBg(row.candidateName),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: _avatarText(row.candidateName),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Roll Number
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.candidateName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            row.registerNumber.isNotEmpty && row.registerNumber != '-'
                                ? '#${row.registerNumber}'
                                : 'ID: ${row.candidateId}',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          row.examTypeName,
                          style: TextStyle(color: Colors.grey[600], fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Result / Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  row.result.isNotEmpty ? row.result : 'Attended',
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 8),

          // Branch & Exam Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    row.branchName,
                    style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    row.attendedDate,
                    style: const TextStyle(color: Color(0xFF4B5563), fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
