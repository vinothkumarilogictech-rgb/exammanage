import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';
import '../providers/branch_context.dart';
import 'package:provider/provider.dart';

class ScheduledCandidatesScreen extends StatefulWidget {
  final String title;
  final String date;
  final bool isToday;

  const ScheduledCandidatesScreen({
    super.key,
    required this.title,
    required this.date,
    this.isToday = true,
  });

  @override
  State<ScheduledCandidatesScreen> createState() => _ScheduledCandidatesScreenState();
}

class _ScheduledCandidatesScreenState extends State<ScheduledCandidatesScreen> {
  final api = DioClient();
  late Future<List<Candidate>> future;
  String searchQuery = '';
  String selectedBranch = 'All';
  String selectedStatus = 'All';
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
    reload();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    super.dispose();
  }

  Future<List<Candidate>> load() async {
    await _branchContext.ensureLoaded();
    final res = await api.candidates(branchId: _branchContext.selectedBranchId);
    final all = (res.data['data'] as List? ?? [])
        .map((e) => Candidate.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    // Filter strictly for this screen's date
    return all.where((c) => c.date == widget.date).toList();
  }

  void reload() {
    setState(() {
      future = load();
    });
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
        title: Text(
          widget.title,
          style: AppBarStyle.titleStyle,
        ),
        actions: [
          IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Candidate>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingView();
          }

          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: reload,
            );
          }

          final rawCandidates = snapshot.requireData;

          // Extract branches and statuses for filters
          final branches = <String>{'All'};
          final statuses = <String>{'All'};
          for (final c in rawCandidates) {
            if (c.branch.isNotEmpty) branches.add(c.branch);
            if (c.status.isNotEmpty) statuses.add(c.status);
          }

          // Apply client-side search & filter
          final filtered = rawCandidates.where((c) {
            final matchesSearch = searchQuery.isEmpty ||
                c.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                c.registerNumber.toLowerCase().contains(searchQuery.toLowerCase()) ||
                c.branch.toLowerCase().contains(searchQuery.toLowerCase()) ||
                c.examType.toLowerCase().contains(searchQuery.toLowerCase());
            final matchesBranch = selectedBranch == 'All' || c.branch == selectedBranch;
            final matchesStatus = selectedStatus == 'All' || c.status == selectedStatus;
            return matchesSearch && matchesBranch && matchesStatus;
          }).toList();

          return Column(
            children: [
              // Search & Filter Header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  children: [
                    // Search box
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Search by candidate name, roll no, branch...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onChanged: (val) => setState(() => searchQuery = val),
                    ),

                    // Filter chips row (if multiple branches/statuses exist)
                    if (branches.length > 2 || statuses.length > 2) ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (branches.length > 2) ...[
                              Text('Branch: ', style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold)),
                              ...branches.map((b) => Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(b),
                                      selected: selectedBranch == b,
                                      onSelected: (_) => setState(() => selectedBranch = b),
                                      selectedColor: const Color(0xFFEDE9FE),
                                      labelStyle: TextStyle(
                                        color: selectedBranch == b ? AppColors.primary : const Color(0xFF4B5563),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Date info banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: widget.isToday ? const Color(0xFFDCFCE7) : const Color(0xFFF0E9FF),
                child: Row(
                  children: [
                    Icon(
                      widget.isToday ? Icons.today_rounded : Icons.event_available_rounded,
                      size: 18,
                      color: widget.isToday ? AppColors.green : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.date.isNotEmpty ? 'Date: ${widget.date}' : 'Scheduled Exams',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: widget.isToday ? const Color(0xFF047857) : AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filtered.length} Record${filtered.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: widget.isToday ? const Color(0xFF047857) : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Candidates List or Empty State
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => reload(),
                  child: filtered.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 100),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.person_off_rounded,
                                      size: 38,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No records',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    searchQuery.isNotEmpty || selectedBranch != 'All'
                                        ? 'No candidates match your filters'
                                        : 'No candidates scheduled for ${widget.title.toLowerCase()}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final c = filtered[i];
                            return _CandidateCard(candidate: c);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================
// CANDIDATE CARD
// ================================================================

class _CandidateCard extends StatelessWidget {
  final Candidate candidate;

  const _CandidateCard({required this.candidate});

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
              // Avatar initial
              CircleAvatar(
                radius: 24,
                backgroundColor: _avatarBg(candidate.name),
                child: Text(
                  initial,
                  style: TextStyle(
                    color: _avatarText(candidate.name),
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name & Roll number / ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
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
                            candidate.registerNumber.isNotEmpty
                                ? '#${candidate.registerNumber}'
                                : 'ID: ${candidate.id}',
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (candidate.email.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              candidate.email,
                              style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Status badge
              _StatusBadge(status: candidate.status),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          const SizedBox(height: 10),

          // Branch & Exam details row
          Row(
            children: [
              // Branch
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        candidate.branch.isNotEmpty ? candidate.branch : 'Main Branch',
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // Exam Type & Time / Date
              Row(
                children: [
                  const Icon(Icons.school_rounded, size: 14, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    candidate.examType.isNotEmpty ? candidate.examType : 'Exam',
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

// ================================================================
// STATUS BADGE WIDGET (COLOR CODED)
// ================================================================

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;

    final s = status.toLowerCase();
    if (s.contains('pass') || s == 'completed') {
      textColor = const Color(0xFF059669); // Green
      bgColor = const Color(0xFFDCFCE7);
    } else if (s.contains('fail') || s == 'cancelled') {
      textColor = const Color(0xFFE11D48); // Red
      bgColor = const Color(0xFFFFE4E6);
    } else if (s == 'in progress' || s == 'in_progress' || s == 'ongoing') {
      textColor = const Color(0xFFD97706); // Yellow / Amber
      bgColor = const Color(0xFFFEF3C7);
    } else if (s == 'scheduled') {
      textColor = const Color(0xFF7C3AED); // Purple
      bgColor = const Color(0xFFEDE9FE);
    } else if (s == 'no show' || s == 'no_show' || s == 'absent') {
      textColor = const Color(0xFFEA580C); // Orange
      bgColor = const Color(0xFFFFEDD5);
    } else {
      // Registered (blue) or default
      textColor = const Color(0xFF2563EB); // Blue
      bgColor = const Color(0xFFDBEAFE);
    }

    final displayText = status.isEmpty ? 'Registered' : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
