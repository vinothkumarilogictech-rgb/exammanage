import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';
import '../widgets/candidate_card.dart';
import '../widgets/common.dart';

class TodayExamsScreen extends StatefulWidget {
  const TodayExamsScreen({super.key});

  @override
  State<TodayExamsScreen> createState() => _TodayExamsScreenState();
}

class _TodayExamsScreenState extends State<TodayExamsScreen> {
  final api = DioClient();
  late Future<List<Candidate>> future;
  String searchQuery = '';
  late final BranchContext _branchContext;

  // Lookups for editing candidates
  List<Map<String, dynamic>> _branchesList = [];
  List<Map<String, dynamic>> _examTypesList = [];

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    future = _loadCandidates();
    _loadLookups();
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

  Future<void> _loadLookups() async {
    try {
      final br = await api.branches();
      final et = await api.examTypes();
      if (!mounted) return;
      setState(() {
        _branchesList = (br.data['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _examTypesList = (et.data['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {}
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    final dt = DateTime.tryParse(raw.trim());
    if (dt != null) return DateTime(dt.year, dt.month, dt.day);

    final parts = raw.trim().split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      } else if (parts[2].length == 4) {
        final d = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final y = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
    }
    return null;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  Future<List<Candidate>> _loadCandidates() async {
    await _branchContext.ensureLoaded();
    final res = await api.candidates(branchId: _branchContext.selectedBranchId);
    final all = (res.data['data'] as List? ?? [])
        .map((e) => Candidate.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter only today's candidates
    return all.where((c) {
      final candDate = _parseDate(c.date);
      if (candDate == null) return false;
      return candDate == today;
    }).toList();
  }

  void reload() {
    setState(() {
      future = _loadCandidates();
    });
  }

  // ================================================================
  // CANDIDATE ACTIONS (Edit, Delete, Status, Remarks, Details)
  // ================================================================

  Future<void> _updateCandidateStatus(int candidateId, String status) async {
    try {
      await api.updateCandidateStatus(candidateId, status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Candidate status updated to $status'),
          backgroundColor: AppColors.green,
        ),
      );
      reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update status: $e')),
      );
    }
  }

  Future<void> _deleteCandidate(Candidate candidate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Candidate'),
        content: Text(
          'Are you sure you want to delete "${candidate.name}"? '
          'This will also remove their exam attempts and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await api.deleteCandidate(candidate.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${candidate.name} deleted successfully.'),
          backgroundColor: AppColors.green,
        ),
      );
      reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to delete candidate: $e')),
      );
    }
  }

  Future<void> _openCandidateDetails(Candidate candidate) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CandidateDetailsScreen(candidate: candidate),
      ),
    );
    if (changed == true && mounted) reload();
  }

  Future<void> _showCandidateRemarks(Candidate candidate) async {
    final controller = TextEditingController(text: candidate.remarks);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Remarks for ${candidate.name}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Enter remarks or notes for this candidate...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Save Remarks',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved == true) {
      try {
        await api.updateCandidate(candidate.id, {
          'remarks': controller.text.trim(),
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remarks updated successfully.'),
            backgroundColor: AppColors.green,
          ),
        );
        reload();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to update remarks: $e')),
        );
      }
    }
  }

  Future<void> _showEditCandidateDialog(Candidate candidate) async {
    final globalBranchId = _branchContext.selectedBranchId;
    if (_branchesList.isEmpty || _examTypesList.isEmpty) {
      await _loadLookups();
    }

    final branches = List<Map<String, dynamic>>.from(_branchesList);
    final examTypes = List<Map<String, dynamic>>.from(_examTypesList);

    List<ExamTeam> teams = [];
    try {
      final tr = await api.teams(status: 'Active', branchId: globalBranchId);
      teams = (tr.data['data'] as List? ?? [])
          .map((e) => ExamTeam.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    int? selectedBranchId = candidate.branchId ?? globalBranchId;
    int? selectedExamTypeId = candidate.examTypeId;
    int? selectedTeamId = candidate.teamId;
    String selectedStatus = candidate.status.toLowerCase() == 'absent'
        ? 'Not Completed'
        : (candidate.status.isEmpty ? 'Registered' : candidate.status);

    final nameCtrl = TextEditingController(text: candidate.name);
    final emailCtrl = TextEditingController(text: candidate.email);
    final phoneCtrl = TextEditingController(text: candidate.phone);
    final remarksCtrl = TextEditingController(text: candidate.remarks);
    final dateCtrl = TextEditingController(text: candidate.date);

    if (!mounted) return;

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                  const Text(
                    'Edit Candidate',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Candidate Name *',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedBranchId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Branch',
                      prefixIcon: Icon(Icons.domain_rounded),
                    ),
                    items: branches
                        .map((b) => DropdownMenuItem<int>(
                              value: b['id'],
                              child: Text('${b['branch_name'] ?? ''}'),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedBranchId = v),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedExamTypeId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Exam Type',
                      prefixIcon: Icon(Icons.menu_book_rounded),
                    ),
                    items: examTypes
                        .map((e) => DropdownMenuItem<int>(
                              value: e['id'],
                              child: Text('${e['name'] ?? ''}'),
                            ))
                        .toList(),
                    onChanged: (v) => setSheetState(() {
                      selectedExamTypeId = v;
                      selectedTeamId = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: selectedTeamId ?? -1,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Team',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<int>(
                        value: -1,
                        child: Text(
                          'Not Assigned',
                          style: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      ...teams
                          .where((t) =>
                              t.examTypeId == null ||
                              selectedExamTypeId == null ||
                              t.examTypeId == selectedExamTypeId)
                          .map((t) => DropdownMenuItem<int>(
                                value: t.id,
                                child: Text(t.name),
                              )),
                    ],
                    onChanged: (v) => setSheetState(
                      () => selectedTeamId = (v == null || v == -1) ? null : v,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Exam Date',
                      prefixIcon: Icon(Icons.calendar_today_rounded),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(dateCtrl.text) ?? DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          dateCtrl.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Remarks',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        try {
                          await api.updateCandidate(candidate.id, {
                            'name': nameCtrl.text.trim(),
                            'email': emailCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'branch_id': selectedBranchId,
                            'exam_type_id': selectedExamTypeId,
                            'team_id': selectedTeamId,
                            'status': selectedStatus,
                            'exam_date': dateCtrl.text.trim(),
                            'remarks': remarksCtrl.text.trim(),
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Error updating: $e')),
                            );
                          }
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidate updated successfully!'),
          backgroundColor: AppColors.green,
        ),
      );
      reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayLabel =
        '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 70,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Exam",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: .2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              todayLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Reload',
          ),
        ],
        flexibleSpace: Container(
          decoration: AppBarStyle.gradientDecoration(),
        ),
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

          final allToday = snapshot.requireData;

          // Apply client-side search query
          final filtered = allToday.where((c) {
            if (searchQuery.isEmpty) return true;
            final q = searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.registerNumber.toLowerCase().contains(q) ||
                c.examType.toLowerCase().contains(q) ||
                c.branch.toLowerCase().contains(q) ||
                c.teamName.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Search Bar
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by candidate name, roll no, exam...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13.5),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => searchQuery = ''),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.searchFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.searchBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.searchBorder),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (val) => setState(() => searchQuery = val),
                ),
              ),

              // Today's Date Banner with record count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFDCFCE7),
                child: Row(
                  children: [
                    const Icon(
                      Icons.today_rounded,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Today's Candidates — $todayLabel",
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF166534),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${filtered.length} ${filtered.length == 1 ? 'Record' : 'Records'}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16A34A),
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
                                      Icons.event_busy_rounded,
                                      size: 38,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No exam candidates today',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    searchQuery.isNotEmpty
                                        ? 'No candidates match your search filter.'
                                        : 'No candidates are scheduled for today.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final candidate = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: CandidateCard(
                                candidate: candidate,
                                onStatusChanged: _updateCandidateStatus,
                                onOpenDetails: _openCandidateDetails,
                                onEditRemarks: _showCandidateRemarks,
                                onEditCandidate: _showEditCandidateDialog,
                                onDeleteCandidate: _deleteCandidate,
                              ),
                            );
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
