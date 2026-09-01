import 'dart:ui';

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
  String filter = 'Month';
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
    final currentMonthStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';

    int registeredThisMonth = 0;
    try {
      final candRes = await api.candidates();
      final allCand = (candRes.data['data'] as List? ?? [])
          .map((e) => Candidate.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      registeredThisMonth = allCand.where((c) {
        if (c.date.startsWith(currentMonthStr)) return true;
        return true;
      }).length;
    } catch (_) {}

    int attendedThisMonth = 0;
    int passedThisMonth = 0;
    try {
      final monthHistoryRes = await api.attendedHistory(month: currentMonthStr);
      final monthRows =
          Map<String, dynamic>.from(monthHistoryRes.data['data'] ?? {})['rows'] as List? ?? [];
      for (final r in monthRows) {
        final resStr = '${r['result'] ?? ''}'.toLowerCase();
        if (resStr.contains('pass') ||
            resStr == 'completed' ||
            resStr == 'fail' ||
            resStr.contains('attended')) {
          attendedThisMonth++;
        }
        if (resStr.contains('pass')) passedThisMonth++;
      }
    } catch (_) {}

    String? date, month, from, to;
    if (filter == 'Today') {
      date = _fmt(now);
    } else if (filter == 'Date' && selectedDate != null) {
      date = _fmt(selectedDate!);
    } else if (filter == 'Month') {
      final targetMonth = monthDate ?? now;
      month =
          '${targetMonth.year.toString().padLeft(4, '0')}-${targetMonth.month.toString().padLeft(2, '0')}';
    } else if (filter == 'Range' && rangeStart != null && rangeEnd != null) {
      from = _fmt(rangeStart!);
      to = _fmt(rangeEnd!);
    }

    final r = await api.attendedHistory(
      date: date,
      month: month,
      dateFrom: from,
      dateTo: to,
    );
    final rows =
        (Map<String, dynamic>.from(r.data['data'] ?? {})['rows'] as List? ?? [])
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

  String _label(DateTime? d) => d == null
      ? 'Select'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
      backgroundColor: const Color(0xFFF6F4FB),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: AppColors.primaryLight,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Attended Candidates', style: AppBarStyle.titleStyle),
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Refresh',
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

          final rows = allRows.where((r) {
            if (searchQuery.trim().isEmpty) return true;
            final q = searchQuery.trim().toLowerCase();
            return r.candidateName.toLowerCase().contains(q) ||
                r.registerNumber.toLowerCase().contains(q) ||
                r.branchName.toLowerCase().contains(q) ||
                r.examTypeName.toLowerCase().contains(q) ||
                r.result.toLowerCase().contains(q);
          }).toList();

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            onRefresh: () async => reload(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 28),
              children: [
                _GlassSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.analytics_rounded,
                        title: 'Monthly Summary',
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              title: 'Registered\nThis Month',
                              value: '$registeredCount',
                              icon: Icons.app_registration_rounded,
                              color: const Color(0xFF2563EB),
                              bgColor: const Color(0xFFEEF4FF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              title: 'Attended\nThis Month',
                              value: '$attendedCount',
                              icon: Icons.how_to_reg_rounded,
                              color: const Color(0xFF7C3AED),
                              bgColor: const Color(0xFFF3EDFF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatBox(
                              title: 'Passed\nThis Month',
                              value: '$passedCount',
                              icon: Icons.verified_rounded,
                              color: const Color(0xFF059669),
                              bgColor: const Color(0xFFEAFBF3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _GlassSection(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: _SectionTitle(
                              icon: Icons.history_rounded,
                              title: 'Attendance History',
                              color: AppColors.green,
                            ),
                          ),
                          _RecordBadge(count: rows.length),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _GlassSearchField(
                        value: searchQuery,
                        onChanged: (value) => setState(() => searchQuery = value),
                        onClear: searchQuery.isEmpty
                            ? null
                            : () => setState(() => searchQuery = ''),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _AttendanceFilterChip(
                              label: 'Today',
                              icon: Icons.today_rounded,
                              selected: filter == 'Today',
                              onTap: () => setState(() {
                                filter = 'Today';
                                future = load();
                              }),
                            ),
                            const SizedBox(width: 7),
                            _AttendanceFilterChip(
                              label: 'Date',
                              icon: Icons.event_rounded,
                              selected: filter == 'Date',
                              onTap: pickDate,
                            ),
                            const SizedBox(width: 7),
                            _AttendanceFilterChip(
                              label: 'Month',
                              icon: Icons.calendar_month_rounded,
                              selected: filter == 'Month',
                              onTap: pickMonth,
                            ),
                            const SizedBox(width: 7),
                            _AttendanceFilterChip(
                              label: 'Date Range',
                              icon: Icons.date_range_rounded,
                              selected: filter == 'Range',
                              onTap: pickRange,
                            ),
                            const SizedBox(width: 7),
                            _AttendanceFilterChip(
                              label: 'All',
                              icon: Icons.all_inclusive_rounded,
                              selected: filter == 'All',
                              onTap: () => setState(() {
                                filter = 'All';
                                future = load();
                              }),
                            ),
                          ],
                        ),
                      ),
                      if (filter == 'Date') ...[
                        const SizedBox(height: 10),
                        _FilterContext(text: 'Selected date: ${_label(selectedDate)}'),
                      ],
                      if (filter == 'Month') ...[
                        const SizedBox(height: 10),
                        _FilterContext(
                          text: 'Selected month: ${monthDate?.month}/${monthDate?.year}',
                        ),
                      ],
                      if (filter == 'Range') ...[
                        const SizedBox(height: 10),
                        _FilterContext(
                          text: 'Range: ${_label(rangeStart)} - ${_label(rangeEnd)}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  _GlassEmptyState(
                    message: filter == 'Month'
                        ? 'No candidates attended this month'
                        : 'No records found for selected filter',
                  )
                else
                  ...rows.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HistoryCard(row: row),
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

class _GlassSection extends StatelessWidget {
  final Widget child;

  const _GlassSection({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 8),
              ),
              const BoxShadow(
                color: Color(0x10000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.11),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.10)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.14),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

class _RecordBadge extends StatelessWidget {
  final int count;

  const _RecordBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Text(
        '$count records',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.10),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
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
          const SizedBox(height: 7),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: color.withOpacity(0.88),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassSearchField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  const _GlassSearchField({
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(
            color: Color(0xFF172033),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: 'Search candidate, roll no, branch...',
            hintStyle: const TextStyle(
              color: Color(0xFF98A0B2),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            suffixIcon: onClear == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: onClear,
                  ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.65),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.10)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.10)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: AppColors.primary.withOpacity(0.42),
                width: 1.2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          ),
        ),
      ),
    );
  }
}

class _AttendanceFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AttendanceFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    AppColors.primaryLight,
                    AppColors.primary,
                  ],
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.70),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withOpacity(0.30)
                : const Color(0xFFE3E6EE),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.20),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? Colors.white : const Color(0xFF687083),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterContext extends StatelessWidget {
  final String text;

  const _FilterContext({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.055),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: AppColors.primary.withOpacity(0.09)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune_rounded, size: 15, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassEmptyState extends StatelessWidget {
  final String message;

  const _GlassEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.06),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.event_busy_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF5E6677),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AttendedCandidate row;

  const _HistoryCard({required this.row});

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
    final initial = row.candidateName.isNotEmpty
        ? row.candidateName[0].toUpperCase()
        : '?';

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

    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withOpacity(0.95)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.065),
                blurRadius: 17,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
              const BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _avatarText(row.candidateName).withOpacity(0.18),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 21,
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
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.candidateName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F1FA),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                row.registerNumber.isNotEmpty && row.registerNumber != '-'
                                    ? '#${row.registerNumber}'
                                    : 'ID: ${row.candidateId}',
                                style: const TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              row.examTypeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF777F90),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeBg.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: badgeText.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: badgeText.withOpacity(0.08),
                          blurRadius: 9,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Text(
                      row.result.isNotEmpty ? row.result : 'Attended',
                      style: TextStyle(
                        color: badgeText,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Container(
                height: 1,
                color: AppColors.primary.withOpacity(0.06),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _InfoPill(
                      icon: Icons.location_on_rounded,
                      text: row.branchName,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _InfoPill(
                    icon: Icons.calendar_today_rounded,
                    text: row.attendedDate,
                    color: const Color(0xFF687083),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.045),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF555E70),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
