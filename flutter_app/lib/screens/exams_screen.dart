import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../app_theme.dart';
import '../config/api_config.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../services/pdf_report_kit.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';
import 'add_candidate_screen.dart';
import '../providers/branch_context.dart';
import 'package:provider/provider.dart';

class ExamsScreen extends StatefulWidget {
  final int initialIndex;
  const ExamsScreen({super.key, this.initialIndex = 0});
  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen>
    with SingleTickerProviderStateMixin {
  final api = DioClient();
  late Future<List<ExamTypeItem>> examTypes;
  late Future<List<ExamSession>> sessions;
  late Future<List<Candidate>> candidates;
  late Future<List<ExamTeam>> teams;
  TabController? _tabController;
  late final BranchContext _branchContext;
  final TextEditingController _candidateSearchCtrl = TextEditingController();
  String _candidateSearchQuery = '';

  TabController get tabController {
    return _tabController ??=
        TabController(
          length: 3,
          vsync: this,
          initialIndex: widget.initialIndex < 0
              ? 0
              : (widget.initialIndex > 2 ? 2 : widget.initialIndex),
        )..addListener(() {
          if (mounted) setState(() {});
        });
  }

  @override
  void initState() {
    super.initState();
    _branchContext = context.read<BranchContext>();
    _branchContext.addListener(_onBranchChanged);
    _tabController =
        TabController(
          length: 3,
          vsync: this,
          initialIndex: widget.initialIndex < 0
              ? 0
              : (widget.initialIndex > 2 ? 2 : widget.initialIndex),
        )..addListener(() {
          if (mounted) setState(() {});
        });
    reload();
  }

  void _onBranchChanged() {
    if (!mounted) return;
    reload();
  }

  @override
  void dispose() {
    _branchContext.removeListener(_onBranchChanged);
    _tabController?.dispose();
    _candidateSearchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _branchesList = [];
  List<Map<String, dynamic>> _examTypesList = [];

  // Team module filter state
  int? _teamFilterId; // null = All Teams, -1 = Unassigned, or specific team id
  DateTime? _teamFilterStartDate;
  DateTime? _teamFilterEndDate;
  String _teamFilterStatus = 'All'; // All, Registered, Not Completed, Rescheduled, Completed

  bool get _isTeamFilterActive =>
      _teamFilterId != null ||
      _teamFilterStartDate != null ||
      _teamFilterEndDate != null ||
      _teamFilterStatus != 'All';

  int get _activeTeamFilterCount {
    int count = 0;
    if (_teamFilterId != null) count++;
    if (_teamFilterStartDate != null || _teamFilterEndDate != null) count++;
    if (_teamFilterStatus != 'All') count++;
    return count;
  }

  void _clearTeamFilters() {
    setState(() {
      _teamFilterId = null;
      _teamFilterStartDate = null;
      _teamFilterEndDate = null;
      _teamFilterStatus = 'All';
    });
  }

  void reload() {
    examTypes = loadExamTypes();
    sessions = loadSessions();
    candidates = loadCandidates();
    teams = loadTeams();
    _loadLookups();
    setState(() {});
  }

  Future<void> _loadLookups() async {
    try {
      final br = await api.branches();
      _branchesList = (br.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final et = await api.examTypes();
      _examTypesList = (et.data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {}
  }

  Future<List<ExamTypeItem>> loadExamTypes() async {
    final r = await api.examTypes();
    return (r.data['data'] as List? ?? const [])
        .map((x) => ExamTypeItem.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }

  Future<List<ExamSession>> loadSessions() async {
    await _branchContext.ensureLoaded();
    final r = await api.sessions(branchId: _branchContext.selectedBranchId);
    return (r.data['data'] as List? ?? const [])
        .map((x) => ExamSession.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }

  Future<List<ExamTeam>> loadTeams() async {
    await _branchContext.ensureLoaded();
    final r = await api.teams(
      status: 'Active',
      branchId: _branchContext.selectedBranchId,
    );
    return (r.data['data'] as List? ?? const [])
        .map((x) => ExamTeam.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to update status: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to delete candidate: $e')));
    }
  }

  Future<List<Candidate>> loadCandidates() async {
    await _branchContext.ensureLoaded();
    final r = await api.candidates(branchId: _branchContext.selectedBranchId);
    return (r.data['data'] as List? ?? const [])
        .map((x) => Candidate.fromMap(Map<String, dynamic>.from(x)))
        .toList();
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.sticky_note_2_rounded,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Candidate Remarks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          candidate.name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Type any note or remark about this candidate...',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF7F5FD),
                  prefixIcon: const Icon(
                    Icons.notes_rounded,
                    color: Color(0xFFEA580C),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF9A22C7),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6C1FB0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded),
                  label: const Text(
                    'Save Remarks',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () async {
                    try {
                      await api.updateCandidate(candidate.id, {
                        'remarks': controller.text.trim(),
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Unable to save remarks: $e')),
                        );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    // Defer disposal until after the sheet's exit animation finishes,
    // so the closing TextField widget never touches a disposed controller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remarks saved.'),
          backgroundColor: AppColors.green,
        ),
      );
      reload();
    }
  }

  // ================================================================
  // HELPER WIDGETS FOR DIALOGS
  // ================================================================

  Widget _fixedBranchField(int branchId, List<Map<String, dynamic>> branches) {
    final match = branches.where((b) => b['id'] == branchId).toList();
    final name = match.isNotEmpty
        ? '${match.first['branch_name'] ?? ''}'
        : 'Selected Branch';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.business_rounded,
            size: 20,
            color: Color(0xFF6B7280),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 18,
            color: Color(0xFF9CA3AF),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 13,
      color: Color(0xFF4B5563),
    ),
  );

  Widget _field(
    TextEditingController ctrl,
    String hint, {
    IconData? icon,
    TextInputType? keyboardType,
  }) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 20) : null,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final uniqueItems = <DropdownMenuItem<T>>[];
    final seen = <T?>{};
    for (final it in items) {
      if (seen.add(it.value)) {
        uniqueItems.add(it);
      }
    }
    final T? effectiveValue = (value != null && seen.contains(value)) ? value : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: effectiveValue,
          hint: Text(
            hint,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B7280),
          ),
          items: uniqueItems,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _formSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) => Container(
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

  Widget _statusChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : const Color(0xFFE5E7EB),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? color : const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? color : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ================================================================
  // ADD CANDIDATE SCREEN
  // ================================================================

  Future<void> _showAddCandidateDialog() async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddCandidateScreen(
          initialBranchId: _branchContext.selectedBranchId,
        ),
      ),
    );
    if (res == true && mounted) {
      reload();
    }
  }

  // ================================================================
  // ADD SESSION DIALOG
  // ================================================================

  Future<void> _showAddSessionDialog() async {
    final globalBranchId = _branchContext.selectedBranchId;
    if (globalBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a branch from Dashboard before adding an exam session.',
          ),
        ),
      );
      return;
    }
    if (_branchesList.isEmpty || _examTypesList.isEmpty) {
      await _loadLookups();
    }

    List<Map<String, dynamic>> branchesList = List.from(_branchesList);
    List<Map<String, dynamic>> examTypesList = List.from(_examTypesList);

    if (branchesList.isEmpty) {
      try {
        final br = await api.branches();
        branchesList = (br.data['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _branchesList = branchesList;
      } catch (_) {}
    }

    if (examTypesList.isEmpty) {
      try {
        final et = await api.examTypes();
        examTypesList = (et.data['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _examTypesList = examTypesList;
      } catch (_) {}
    }

    if (globalBranchId != null) {
      branchesList = branchesList
          .where((b) => b['id'] == globalBranchId)
          .toList();
    }
    int? selectedBranchId =
        globalBranchId ??
        (branchesList.isNotEmpty ? branchesList.first['id'] : null);
    int? selectedExamTypeId = examTypesList.isNotEmpty
        ? examTypesList.first['id']
        : null;
    final dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
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
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
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
                        gradient: brandLinearGradient(),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.note_add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Exam Session',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Branch is controlled globally from Dashboard.
                _label('Branch'),
                const SizedBox(height: 6),
                _fixedBranchField(globalBranchId, branchesList),
                const SizedBox(height: 14),

                // Exam Type
                _label('Exam Type'),
                const SizedBox(height: 6),
                _dropdown<int>(
                  value: selectedExamTypeId,
                  hint: 'Select exam type',
                  items: examTypesList
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e['id'],
                          child: Row(
                            children: [
                              const Icon(
                                Icons.school_rounded,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${e['name'] ?? ''}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setSheetState(() => selectedExamTypeId = val),
                ),

                const SizedBox(height: 14),
                _label('Exam Date'),
                const SizedBox(height: 6),
                TextField(
                  controller: dateCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: 'Select date',
                    suffixIcon: const Icon(Icons.calendar_today_rounded),
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
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      dateCtrl.text =
                          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Start Time'),
                          const SizedBox(height: 6),
                          _field(startCtrl, 'HH:MM'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('End Time'),
                          const SizedBox(height: 6),
                          _field(endCtrl, 'HH:MM'),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Fee'),
                          const SizedBox(height: 6),
                          _field(
                            feeCtrl,
                            '0.00',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Seats'),
                          const SizedBox(height: 6),
                          _field(
                            capacityCtrl,
                            '0',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (dateCtrl.text.isEmpty ||
                          selectedBranchId == null ||
                          selectedExamTypeId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Fill all required fields'),
                          ),
                        );
                        return;
                      }
                      try {
                        // Auto-create or find existing branch-exam mapping
                        int? mappingId;
                        try {
                          final mapResp = await api.createBranchMapping({
                            'branch_id': selectedBranchId,
                            'exam_type_id': selectedExamTypeId,
                          });
                          mappingId = mapResp.data['data']?['id'];
                        } catch (_) {
                          // Mapping may already exist — find it
                          final existing = await api.branchMappings(
                            branchId: selectedBranchId,
                          );
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
                              const SnackBar(
                                content: Text(
                                  'Could not resolve branch-exam mapping',
                                ),
                              ),
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
                            const SnackBar(
                              content: Text('Session created!'),
                              backgroundColor: AppColors.green,
                            ),
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) reload(); });
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: const Text(
                      'Create Session',
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

  // ================================================================
  // BUILD
  // ================================================================

  Future<void> _showAddExamTypeDialog() async {
    // The Add Exam form uses the existing English-language exam catalog.
    // If the user selects "Others", they can enter a custom exam name manually.
    if (_examTypesList.isEmpty) {
      await _loadLookups();
    }

    final englishExamNames = <String>{
      for (final exam in _examTypesList)
        if ('${exam['language'] ?? ''}'.trim().toLowerCase() == 'english' &&
            '${exam['name'] ?? ''}'.trim().isNotEmpty)
          '${exam['name']}'.trim(),
    }.toList();
    englishExamNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    String? selectedExam = englishExamNames.isNotEmpty
        ? englishExamNames.first
        : null;
    final customExamCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
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
                        gradient: brandLinearGradient(),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _label('Exam Name *'),
                const SizedBox(height: 6),
                _dropdown<String>(
                  value: selectedExam,
                  hint: 'Select English exam',
                  items: [
                    ...englishExamNames.map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              size: 18,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: '__others__',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                          SizedBox(width: 8),
                          Text('Others'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setSheetState(() {
                      selectedExam = value;
                      if (value != '__others__') customExamCtrl.clear();
                    });
                  },
                ),
                if (selectedExam == '__others__') ...[
                  const SizedBox(height: 14),
                  _label('Enter Exam Name *'),
                  const SizedBox(height: 6),
                  _field(
                    customExamCtrl,
                    'e.g. PTE, GRE, Duolingo',
                    icon: Icons.edit_rounded,
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      final examName = selectedExam == '__others__'
                          ? customExamCtrl.text.trim()
                          : (selectedExam ?? '').trim();
                      if (examName.isEmpty || selectedExam == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select an exam or choose Others and enter a name',
                            ),
                          ),
                        );
                        return;
                      }
                      try {
                        await api.createExamType({
                          'name': examName,
                          'language': selectedExam == '__others__'
                              ? 'Other'
                              : 'English',
                          // Description is intentionally not collected in the UI.
                          'description': '',
                          'status': 'Active',
                        });
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Exam type added successfully!'),
                              backgroundColor: AppColors.green,
                            ),
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) reload(); });
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    },
                    child: const Text(
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
    customExamCtrl.dispose();
  }

  Future<void> _showAddTeamDialog() async {
    final globalBranchId = _branchContext.selectedBranchId;
    if (globalBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a branch from Dashboard before adding a team.',
          ),
        ),
      );
      return;
    }
    if (_examTypesList.isEmpty) await _loadLookups();
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    int? selectedExamTypeId = _examTypesList.isNotEmpty
        ? _examTypesList.first['id']
        : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: brandLinearGradient(),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _label('Team Name *'),
                const SizedBox(height: 6),
                _field(
                  nameCtrl,
                  'e.g. CELPIP Partner Team',
                  icon: Icons.groups_rounded,
                ),
                const SizedBox(height: 14),
                _label('Location'),
                const SizedBox(height: 6),
                _field(
                  locationCtrl,
                  'Team location / service area',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),
                _label('Phone Number'),
                const SizedBox(height: 6),
                _field(
                  phoneCtrl,
                  'Team contact number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _label('Exam Provided For'),
                const SizedBox(height: 6),
                _dropdown<int>(
                  value: selectedExamTypeId,
                  hint: 'Select exam',
                  items: _examTypesList
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e['id'],
                          child: Text('${e['name'] ?? ''}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedExamTypeId = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Team name is required'),
                          ),
                        );
                        return;
                      }
                      try {
                        await api.createTeam({
                          'name': nameCtrl.text.trim(),
                          'location': locationCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'branch_id': globalBranchId,
                          'exam_type_id': selectedExamTypeId,
                          'status': 'Active',
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Team added successfully!'),
                              backgroundColor: AppColors.green,
                            ),
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) reload(); });
                        }
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    icon: const Icon(Icons.add_rounded),
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

  Future<void> _showEditTeamDialog(ExamTeam team) async {
    if (_examTypesList.isEmpty) await _loadLookups();
    final nameCtrl = TextEditingController(text: team.name);
    final locationCtrl = TextEditingController(text: team.location);
    final phoneCtrl = TextEditingController(text: team.phone);
    int? selectedExamTypeId = team.examTypeId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: brandLinearGradient(),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Team',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _label('Team Name *'),
                const SizedBox(height: 6),
                _field(
                  nameCtrl,
                  'e.g. CELPIP Partner Team',
                  icon: Icons.groups_rounded,
                ),
                const SizedBox(height: 14),
                _label('Location'),
                const SizedBox(height: 6),
                _field(
                  locationCtrl,
                  'Team location / service area',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),
                _label('Phone Number'),
                const SizedBox(height: 6),
                _field(
                  phoneCtrl,
                  'Team contact number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                _label('Exam Provided For'),
                const SizedBox(height: 6),
                _dropdown<int>(
                  value: selectedExamTypeId,
                  hint: 'Select exam',
                  items: _examTypesList
                      .map(
                        (e) => DropdownMenuItem<int>(
                          value: e['id'],
                          child: Text('${e['name'] ?? ''}'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setSheetState(() => selectedExamTypeId = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Team name is required'),
                          ),
                        );
                        return;
                      }
                      try {
                        await api.updateTeam(team.id, {
                          'name': nameCtrl.text.trim(),
                          'location': locationCtrl.text.trim(),
                          'phone': phoneCtrl.text.trim(),
                          'exam_type_id': selectedExamTypeId,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Team updated successfully!'),
                              backgroundColor: AppColors.green,
                            ),
                          );
                          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) reload(); });
                        }
                      } catch (e) {
                        if (ctx.mounted)
                          ScaffoldMessenger.of(
                            ctx,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'Save',
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

  String _csvEscape(dynamic value) =>
      '"${'${value ?? ''}'.replaceAll('"', '""')}"';

  List<Candidate> _filterCandidateRecords(
    List<Candidate> allCandidates, {
    int? teamIdOverride,
  }) {
    final effectiveTeamFilter = teamIdOverride ?? _teamFilterId;
    return allCandidates.where((c) {
      // 1. Team filter
      if (effectiveTeamFilter != null) {
        if (effectiveTeamFilter == -1) {
          // Unassigned candidates
          if (c.teamId != null && c.teamId! > 0) return false;
        } else {
          // Specific team
          if (c.teamId != effectiveTeamFilter) return false;
        }
      }

      // 2. Date range filter (exam date)
      if (_teamFilterStartDate != null || _teamFilterEndDate != null) {
        if (c.date.trim().isEmpty) return false;
        final rawDate = c.date.trim().split('T').first;
        final parts = rawDate.split(RegExp(r'[-/]'));
        DateTime? examDate;
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            // YYYY-MM-DD
            examDate = DateTime.tryParse(rawDate);
          } else if (parts[2].length == 4) {
            // DD-MM-YYYY
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? 2026;
            examDate = DateTime(year, month, day);
          }
        } else {
          examDate = DateTime.tryParse(rawDate);
        }

        if (examDate == null) return false;

        if (_teamFilterStartDate != null) {
          final start = DateTime(
            _teamFilterStartDate!.year,
            _teamFilterStartDate!.month,
            _teamFilterStartDate!.day,
          );
          if (examDate.isBefore(start)) return false;
        }
        if (_teamFilterEndDate != null) {
          final end = DateTime(
            _teamFilterEndDate!.year,
            _teamFilterEndDate!.month,
            _teamFilterEndDate!.day,
            23,
            59,
            59,
          );
          if (examDate.isAfter(end)) return false;
        }
      }

      // 3. Status filter
      if (_teamFilterStatus != 'All') {
        final cStatus = c.status.toLowerCase().trim() == 'absent'
            ? 'not completed'
            : c.status.toLowerCase().trim();
        final targetStatus = _teamFilterStatus.toLowerCase().trim();
        if (cStatus != targetStatus) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _showTeamFilterBottomSheet(List<ExamTeam> teamsList) async {
    int? tempTeamId = _teamFilterId;
    DateTime? tempStartDate = _teamFilterStartDate;
    DateTime? tempEndDate = _teamFilterEndDate;
    String tempStatus = _teamFilterStatus;
    String? dateError;

    String formatDate(DateTime? d) {
      if (d == null) return '';
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.filter_alt_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Filter Exam & Team Records',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setSheetState(() {
                            tempTeamId = null;
                            tempStartDate = null;
                            tempEndDate = null;
                            tempStatus = 'All';
                            dateError = null;
                          });
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Team Selector
                  _label('Team'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int?>(
                    value: tempTeamId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.groups_rounded, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('All Teams'),
                      ),
                      const DropdownMenuItem<int?>(
                        value: -1,
                        child: Text('Unassigned (No Team)'),
                      ),
                      ...teamsList.map(
                        (t) => DropdownMenuItem<int?>(
                          value: t.id,
                          child: Text(
                            t.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (v) => setSheetState(() => tempTeamId = v),
                  ),

                  const SizedBox(height: 16),

                  // 2. Date Range
                  _label('Exam Date Range'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                tempStartDate = picked;
                                if (tempEndDate != null &&
                                    tempEndDate!.isBefore(tempStartDate!)) {
                                  dateError =
                                      'End date must not be earlier than start date';
                                } else {
                                  dateError = null;
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tempStartDate == null
                                        ? 'Start Date'
                                        : formatDate(tempStartDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: tempStartDate == null
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: tempStartDate == null
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                if (tempStartDate != null)
                                  GestureDetector(
                                    onTap: () => setSheetState(() {
                                      tempStartDate = null;
                                      dateError = null;
                                    }),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: tempEndDate ?? tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setSheetState(() {
                                tempEndDate = picked;
                                if (tempStartDate != null &&
                                    tempEndDate!.isBefore(tempStartDate!)) {
                                  dateError =
                                      'End date must not be earlier than start date';
                                } else {
                                  dateError = null;
                                }
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    tempEndDate == null
                                        ? 'End Date'
                                        : formatDate(tempEndDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: tempEndDate == null
                                          ? FontWeight.w500
                                          : FontWeight.w700,
                                      color: tempEndDate == null
                                          ? const Color(0xFF9CA3AF)
                                          : const Color(0xFF1F2937),
                                    ),
                                  ),
                                ),
                                if (tempEndDate != null)
                                  GestureDetector(
                                    onTap: () => setSheetState(() {
                                      tempEndDate = null;
                                      dateError = null;
                                    }),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Color(0xFF9CA3AF),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (dateError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        dateError!,
                        style: const TextStyle(
                          color: AppColors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 3. Status Selector
                  _label('Status'),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        'All',
                        'Registered',
                        'Not Completed',
                        'Rescheduled',
                        'Completed',
                      ].map((status) {
                        final isSel = tempStatus == status;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(status),
                            selected: isSel,
                            selectedColor: const Color(0xFFEDE9FE),
                            labelStyle: TextStyle(
                              color: isSel
                                  ? AppColors.primary
                                  : const Color(0xFF4B5563),
                              fontWeight:
                                  isSel ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                            side: BorderSide(
                              color: isSel
                                  ? AppColors.primary
                                  : const Color(0xFFE5E7EB),
                            ),
                            onSelected: (_) {
                              setSheetState(() => tempStatus = status);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 4. Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _clearTeamFilters();
                            Navigator.pop(ctx);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Clear Filters'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (tempStartDate != null &&
                                tempEndDate != null &&
                                tempEndDate!.isBefore(tempStartDate!)) {
                              setSheetState(() {
                                dateError =
                                    'End date must not be earlier than start date';
                              });
                              return;
                            }
                            setState(() {
                              _teamFilterId = tempTeamId;
                              _teamFilterStartDate = tempStartDate;
                              _teamFilterEndDate = tempEndDate;
                              _teamFilterStatus = tempStatus;
                            });
                            Navigator.pop(ctx);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showOverallReportActions() => _showTeamReportActions();

  Future<void> _showTeamReportActions({ExamTeam? specificTeam}) async {
    final teamList = await teams;
    final allCandidates = await candidates;
    final filtered = _filterCandidateRecords(
      allCandidates,
      teamIdOverride: specificTeam?.id,
    );

    if (!mounted) return;

    final targetTeamName = specificTeam?.name ??
        (_teamFilterId != null
            ? (teamList.any((t) => t.id == _teamFilterId)
                ? teamList.firstWhere((t) => t.id == _teamFilterId).name
                : (_teamFilterId == -1
                    ? 'Unassigned Candidates'
                    : 'Team #$_teamFilterId'))
            : 'All Teams');

    String dateRangeSummary = 'All Dates';
    if (_teamFilterStartDate != null && _teamFilterEndDate != null) {
      dateRangeSummary =
          '${_teamFilterStartDate!.year}-${_teamFilterStartDate!.month.toString().padLeft(2, '0')}-${_teamFilterStartDate!.day.toString().padLeft(2, '0')} to ${_teamFilterEndDate!.year}-${_teamFilterEndDate!.month.toString().padLeft(2, '0')}-${_teamFilterEndDate!.day.toString().padLeft(2, '0')}';
    } else if (_teamFilterStartDate != null) {
      dateRangeSummary =
          'From ${_teamFilterStartDate!.year}-${_teamFilterStartDate!.month.toString().padLeft(2, '0')}-${_teamFilterStartDate!.day.toString().padLeft(2, '0')}';
    } else if (_teamFilterEndDate != null) {
      dateRangeSummary =
          'Up to ${_teamFilterEndDate!.year}-${_teamFilterEndDate!.month.toString().padLeft(2, '0')}-${_teamFilterEndDate!.day.toString().padLeft(2, '0')}';
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
              const SizedBox(height: 18),
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
                      Icons.summarize_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          specificTeam != null
                              ? '${specificTeam.name} Report'
                              : 'Team Report',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Scope: $targetTeamName • Dates: $dateRangeSummary • Status: $_teamFilterStatus (${filtered.length} records)',
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFDC2626),
                ),
                title: const Text('Download PDF'),
                subtitle: Text('Export ${filtered.length} matching records'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFilteredTeamPdf(
                    teamName: targetTeamName,
                    candidates: filtered,
                    allTeams: teamList,
                    dateRangeText: dateRangeSummary,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.table_chart_rounded,
                  color: Color(0xFF059669),
                ),
                title: const Text('Export Excel (CSV)'),
                subtitle: Text('Export ${filtered.length} matching records'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _exportFilteredTeamExcel(
                    teamName: targetTeamName,
                    candidates: filtered,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportFilteredTeamPdf({
    required String teamName,
    required List<Candidate> candidates,
    required List<ExamTeam> allTeams,
    required String dateRangeText,
  }) async {
    if (candidates.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Empty Report'),
            content: const Text(
              'No records match the selected filters to generate a report. '
              'Please adjust your filter selections and try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    try {
      final logo = await loadBrandLogo();
      final document = pw.Document();

      // Compute status breakdown
      int regCount = 0;
      int notCompCount = 0;
      int reschedCount = 0;
      int compCount = 0;
      for (final c in candidates) {
        final st = c.status.toLowerCase().trim();
        if (st == 'registered') {
          regCount++;
        } else if (st == 'not completed' || st == 'absent') {
          notCompCount++;
        } else if (st == 'rescheduled') {
          reschedCount++;
        } else if (st == 'completed') {
          compCount++;
        }
      }

      // Compute team breakdown
      final Map<String, List<Candidate>> teamMap = {};
      for (final c in candidates) {
        final tName = c.teamName.isNotEmpty ? c.teamName : 'Unassigned';
        teamMap.putIfAbsent(tName, () => []).add(c);
      }

      final now = DateTime.now();
      final genDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      document.addPage(
        pw.MultiPage(
          pageFormat: pdf.PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => [
            pdfReportHeader(
              logo: logo,
              title: 'Team-Based Exam Report',
              subtitle: 'Team: $teamName',
              docDate: 'Generated: $genDate',
            ),
            pw.SizedBox(height: 12),

            // Filter Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfBrand.tint,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Report & Filter Summary',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 11.5,
                      color: PdfBrand.primaryDark,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'Team Scope: $teamName',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfBrand.textDark,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'Exam Date Range: $dateRangeText',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfBrand.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'Status Filter: $_teamFilterStatus',
                          style: const pw.TextStyle(
                            fontSize: 9.5,
                            color: PdfBrand.textDark,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          'Total Candidates: ${candidates.length}',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfBrand.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Status Breakdown Summary
            pw.Text(
              'Status Breakdown',
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfBrand.textDark,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                'Registered',
                'Not Completed',
                'Rescheduled',
                'Completed',
                'Total Candidates'
              ],
              data: [
                [
                  '$regCount',
                  '$notCompCount',
                  '$reschedCount',
                  '$compCount',
                  '${candidates.length}'
                ],
              ],
              columnWidths: const {
                0: pw.FlexColumnWidth(1),
                1: pw.FlexColumnWidth(1),
                2: pw.FlexColumnWidth(1),
                3: pw.FlexColumnWidth(1),
                4: pw.FlexColumnWidth(1),
              },
              headerStyle: pdfTableHeaderStyle(fontSize: 8.5),
              headerDecoration: pdfTableHeaderDecoration,
              cellAlignment: pw.Alignment.center,
              cellStyle: const pw.TextStyle(fontSize: 8.5, color: PdfBrand.textDark),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            ),
            pw.SizedBox(height: 14),

            // Team-Wise Breakdown (if more than 1 group)
            if (teamMap.length > 1) ...[
              pw.Text(
                'Team-Wise Breakdown',
                style: pw.TextStyle(
                  fontSize: 11.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfBrand.textDark,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.TableHelper.fromTextArray(
                headers: [
                  'Team Name',
                  'Registered',
                  'Not Completed',
                  'Rescheduled',
                  'Completed',
                  'Total'
                ],
                data: teamMap.entries.map((e) {
                  int reg = 0, notComp = 0, resched = 0, comp = 0;
                  for (final c in e.value) {
                    final st = c.status.toLowerCase().trim();
                    if (st == 'registered') {
                      reg++;
                    } else if (st == 'not completed' || st == 'absent') {
                      notComp++;
                    } else if (st == 'rescheduled') {
                      resched++;
                    } else if (st == 'completed') {
                      comp++;
                    }
                  }
                  return [
                    e.key,
                    '$reg',
                    '$notComp',
                    '$resched',
                    '$comp',
                    '${e.value.length}'
                  ];
                }).toList(),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                  3: pw.FlexColumnWidth(1),
                  4: pw.FlexColumnWidth(1),
                  5: pw.FlexColumnWidth(1),
                },
                headerStyle: pdfTableHeaderStyle(fontSize: 8.5),
                headerDecoration: pdfTableHeaderDecoration,
                headerAlignment: pw.Alignment.centerLeft,
                cellAlignment: pw.Alignment.center,
                cellAlignments: const {0: pw.Alignment.centerLeft},
                cellStyle: const pw.TextStyle(fontSize: 8, color: PdfBrand.textDark),
                cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                oddRowDecoration: pdfTableOddRowDecoration,
              ),
              pw.SizedBox(height: 14),
            ],

            // Candidate Details Table
            pw.Text(
              'Filtered Candidate Records (${candidates.length})',
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfBrand.textDark,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                'S.No',
                'Candidate',
                'Reg #',
                'Exam',
                'Date',
                'Team',
                'Status',
                'Remarks'
              ],
              data: candidates.asMap().entries.map((entry) {
                final idx = entry.key + 1;
                final c = entry.value;
                return [
                  '$idx',
                  c.name,
                  c.registerNumber.isNotEmpty ? c.registerNumber : '-',
                  c.examType.isNotEmpty ? c.examType : '-',
                  c.date.isNotEmpty ? c.date : '-',
                  c.teamName.isNotEmpty ? c.teamName : 'Unassigned',
                  c.status.isNotEmpty ? c.status : '-',
                  c.remarks.isNotEmpty ? c.remarks : '-',
                ];
              }).toList(),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.5),
                1: pw.FlexColumnWidth(1.8),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.1),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(1.4),
                6: pw.FlexColumnWidth(1.2),
                7: pw.FlexColumnWidth(1.4),
              },
              headerStyle: pdfTableHeaderStyle(fontSize: 8),
              headerDecoration: pdfTableHeaderDecoration,
              headerAlignment: pw.Alignment.centerLeft,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: const {0: pw.Alignment.center},
              cellStyle: const pw.TextStyle(fontSize: 7.5, color: PdfBrand.textDark),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
              oddRowDecoration: pdfTableOddRowDecoration,
            ),
          ],
        ),
      );

      final safe = teamName.replaceAll(RegExp(r'\W+'), '_');
      await Printing.layoutPdf(
        onLayout: (format) async => document.save(),
        name: '${safe}_team_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportFilteredTeamExcel({
    required String teamName,
    required List<Candidate> candidates,
  }) async {
    if (candidates.isEmpty) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Empty Report'),
            content: const Text(
              'No records match the selected filters to export.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final headers = [
      'S.No',
      'Candidate Name',
      'Register Number',
      'Exam Type',
      'Exam Date',
      'Team Name',
      'Status',
      'Remarks',
      'Branch',
    ];
    final buffer = StringBuffer()..writeln(headers.map(_csvEscape).join(','));
    for (int i = 0; i < candidates.length; i++) {
      final c = candidates[i];
      final row = {
        'S.No': i + 1,
        'Candidate Name': c.name,
        'Register Number': c.registerNumber,
        'Exam Type': c.examType,
        'Exam Date': c.date,
        'Team Name': c.teamName.isNotEmpty ? c.teamName : 'Unassigned',
        'Status': c.status,
        'Remarks': c.remarks,
        'Branch': c.branch,
      };
      buffer.writeln(headers.map((h) => _csvEscape(row[h])).join(','));
    }

    final safe = teamName.replaceAll(RegExp(r'\W+'), '_');
    await Printing.sharePdf(
      bytes: Uint8List.fromList(buffer.toString().codeUnits),
      filename:
          '${safe}_team_report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
  }

  Widget _buildFilterBadge(String label, {required VoidCallback onDelete}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC4B5FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMiniTag(
    String label,
    int count,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = tabController;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
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
              colors: [Color(0xFF6C1FB0), Color(0xFF9A22C7), Color(0xFFE0189E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x55FF7A18),
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
        ),
        title: const Text('Exam', style: AppBarStyle.titleStyle),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            icon: const Icon(Icons.person_rounded),
          ),
          IconButton(
            onPressed: reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: controller,
              indicator: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(11),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              tabs: const [
                Tab(text: 'Exam'),
                Tab(text: 'Candidates'),
                Tab(text: 'Team'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: controller,
        children: [
          // ======================================
          // EXAM TAB
          // ======================================
          FutureBuilder<List<ExamTypeItem>>(
            future: examTypes,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (s.hasError) {
                return ErrorView(message: '${s.error}', onRetry: reload);
              }
              final types = s.requireData;
              if (types.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 56,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No exams registered',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showAddExamTypeDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: types.length,
                itemBuilder: (c, i) => _ExamTypeCard(examType: types[i]),
              );
            },
          ),

          // ======================================
          // CANDIDATES TAB
          // ======================================
          FutureBuilder<List<Candidate>>(
            future: candidates,
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (s.hasError) {
                return ErrorView(message: '${s.error}', onRetry: reload);
              }
              final rows = s.requireData;
              if (rows.isEmpty && _candidateSearchQuery.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 56,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No candidates',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _showAddCandidateDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('Add'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final query = _candidateSearchQuery.trim().toLowerCase();
              final filteredRows = query.isEmpty
                  ? rows
                  : rows.where((cand) => cand.name.toLowerCase().contains(query)).toList();

              return Column(
                children: [
                  // Candidate Name Search Bar
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: TextField(
                      controller: _candidateSearchCtrl,
                      onChanged: (val) {
                        setState(() {
                          _candidateSearchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search candidate by name...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF6C1FB0),
                          size: 20,
                        ),
                        suffixIcon: _candidateSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _candidateSearchCtrl.clear();
                                  setState(() {
                                    _candidateSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceAlt,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF9A22C7),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filteredRows.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_search_rounded,
                                    size: 52,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No candidates match "$_candidateSearchQuery"',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: () {
                                      _candidateSearchCtrl.clear();
                                      setState(() {
                                        _candidateSearchQuery = '';
                                      });
                                    },
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    label: const Text('Clear search'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: filteredRows.length,
                            itemBuilder: (c, i) => _CandidateCard(
                              candidate: filteredRows[i],
                              onStatusChanged: _updateCandidateStatus,
                              onOpenDetails: _openCandidateDetails,
                              onEditRemarks: _showCandidateRemarks,
                              onEditCandidate: _showEditCandidateDialog,
                              onDeleteCandidate: _deleteCandidate,
                            ),
                          ),
                  ),
                ],
              );
            },
          ),

          // ======================================
          // TEAM TAB
          // ======================================
          FutureBuilder<List<dynamic>>(
            future: Future.wait([
              teams,
              candidates,
            ]),
            builder: (c, s) {
              if (s.connectionState != ConnectionState.done) {
                return const LoadingView();
              }
              if (s.hasError) {
                return ErrorView(message: '${s.error}', onRetry: reload);
              }
              final teamRows = (s.requireData[0] as List).cast<ExamTeam>();
              final candidateRows = (s.requireData[1] as List).cast<Candidate>();
              final filteredCandidates = _filterCandidateRecords(candidateRows);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isTeamFilterActive
                                    ? 'Filtered Records'
                                    : 'Exam Teams',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                _isTeamFilterActive
                                    ? '${filteredCandidates.length} candidate record${filteredCandidates.length == 1 ? '' : 's'} matching filters'
                                    : 'Teams supporting your exams',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Filter button with active filter counter badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showTeamFilterBottomSheet(teamRows),
                              icon: Icon(
                                Icons.filter_list_rounded,
                                size: 17,
                                color: _isTeamFilterActive
                                    ? AppColors.primary
                                    : const Color(0xFF4B5563),
                              ),
                              label: Text(
                                'Filter',
                                style: TextStyle(
                                  color: _isTeamFilterActive
                                      ? AppColors.primary
                                      : const Color(0xFF374151),
                                  fontWeight: _isTeamFilterActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: _isTeamFilterActive
                                    ? const Color(0xFFF3E8FF)
                                    : Colors.white,
                                side: BorderSide(
                                  color: _isTeamFilterActive
                                      ? AppColors.primary
                                      : const Color(0xFFD1D5DB),
                                  width: _isTeamFilterActive ? 1.5 : 1,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            if (_activeTeamFilterCount > 0)
                              Positioned(
                                top: -3,
                                right: -3,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$_activeTeamFilterCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        // Reports button
                        OutlinedButton.icon(
                          onPressed: (teamRows.isEmpty && candidateRows.isEmpty)
                              ? null
                              : _showOverallReportActions,
                          icon: const Icon(Icons.download_rounded, size: 17),
                          label: const Text('Reports'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: Color(0xFFD8B4FE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // If filter is active, show filter chips and count summary
                  if (_isTeamFilterActive)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (_teamFilterId != null) ...[
                                  _buildFilterBadge(
                                    'Team: ${_teamFilterId == -1 ? 'Unassigned' : (teamRows.any((t) => t.id == _teamFilterId) ? teamRows.firstWhere((t) => t.id == _teamFilterId).name : 'Team #$_teamFilterId')}',
                                    onDelete: () => setState(() => _teamFilterId = null),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (_teamFilterStartDate != null || _teamFilterEndDate != null) ...[
                                  _buildFilterBadge(
                                    _teamFilterStartDate != null && _teamFilterEndDate != null
                                        ? '${_teamFilterStartDate!.year}-${_teamFilterStartDate!.month.toString().padLeft(2, '0')}-${_teamFilterStartDate!.day.toString().padLeft(2, '0')} to ${_teamFilterEndDate!.year}-${_teamFilterEndDate!.month.toString().padLeft(2, '0')}-${_teamFilterEndDate!.day.toString().padLeft(2, '0')}'
                                        : (_teamFilterStartDate != null
                                            ? 'From ${_teamFilterStartDate!.year}-${_teamFilterStartDate!.month.toString().padLeft(2, '0')}-${_teamFilterStartDate!.day.toString().padLeft(2, '0')}'
                                            : 'Up to ${_teamFilterEndDate!.year}-${_teamFilterEndDate!.month.toString().padLeft(2, '0')}-${_teamFilterEndDate!.day.toString().padLeft(2, '0')}'),
                                    onDelete: () => setState(() {
                                      _teamFilterStartDate = null;
                                      _teamFilterEndDate = null;
                                    }),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                if (_teamFilterStatus != 'All') ...[
                                  _buildFilterBadge(
                                    'Status: $_teamFilterStatus',
                                    onDelete: () => setState(() => _teamFilterStatus = 'All'),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                InkWell(
                                  onTap: _clearTeamFilters,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEE2E2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: const Color(0xFFFECACA)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.clear_all_rounded, size: 14, color: Color(0xFFDC2626)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Clear All',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Status metrics summary bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Total: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                                    _buildStatusMiniTag('Total', filteredCandidates.length, const Color(0xFF1F2937), const Color(0xFFE5E7EB)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Reg: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                                    _buildStatusMiniTag(
                                      'Registered',
                                      filteredCandidates.where((c) => c.status.toLowerCase().trim() == 'registered').length,
                                      const Color(0xFF1D4ED8),
                                      const Color(0xFFDBEAFE),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Not Comp: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                                    _buildStatusMiniTag(
                                      'Not Completed',
                                      filteredCandidates.where((c) => c.status.toLowerCase().trim() == 'not completed' || c.status.toLowerCase().trim() == 'absent').length,
                                      const Color(0xFFC2410C),
                                      const Color(0xFFFFEDD5),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Resched: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                                    _buildStatusMiniTag(
                                      'Rescheduled',
                                      filteredCandidates.where((c) => c.status.toLowerCase().trim() == 'rescheduled').length,
                                      const Color(0xFF6D28D9),
                                      const Color(0xFFEDE9FE),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Comp: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                                    _buildStatusMiniTag(
                                      'Completed',
                                      filteredCandidates.where((c) => c.status.toLowerCase().trim() == 'completed').length,
                                      const Color(0xFF15803D),
                                      const Color(0xFFDCFCE7),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: _isTeamFilterActive
                        ? (filteredCandidates.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.filter_alt_off_rounded,
                                        size: 56,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No candidate records match filters',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Try adjusting team, date range, or status filters.',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                        onPressed: _clearTeamFilters,
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('Reset Filters'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                                itemCount: filteredCandidates.length,
                                itemBuilder: (c, i) => _CandidateCard(
                                  candidate: filteredCandidates[i],
                                  onStatusChanged: _updateCandidateStatus,
                                  onOpenDetails: _openCandidateDetails,
                                  onEditRemarks: _showCandidateRemarks,
                                  onEditCandidate: _showEditCandidateDialog,
                                  onDeleteCandidate: _deleteCandidate,
                                ),
                              ))
                        : (teamRows.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.groups_outlined,
                                      size: 60,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No teams added yet',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: _showAddTeamDialog,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                                itemCount: teamRows.length,
                                itemBuilder: (c, i) => _TeamCard(
                                  team: teamRows[i],
                                  onReport: () => _showTeamReportActions(specificTeam: teamRows[i]),
                                  onEdit: () => _showEditTeamDialog(teamRows[i]),
                                  onDelete: () async {
                                    try {
                                      await api.deleteTeam(teamRows[i].id);
                                      reload();
                                    } catch (e) {
                                      if (mounted)
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$e')),
                                        );
                                    }
                                  },
                                ),
                              )),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: controller.index == 1
            ? const Color(0xFF059669)
            : AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: controller.index == 0
            ? _showAddExamTypeDialog
            : controller.index == 1
            ? _showAddCandidateDialog
            : _showAddTeamDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showEditCandidateDialog(Candidate candidate) async {
    final globalBranchId = _branchContext.selectedBranchId;
    final currentBranchId = candidate.branchId ?? globalBranchId;
    if (currentBranchId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a branch from Dashboard before editing a candidate.',
          ),
        ),
      );
      return;
    }

    await _loadLookups();
    final branches = List<Map<String, dynamic>>.from(_branchesList);
    final examTypes = List<Map<String, dynamic>>.from(_examTypesList);
    List<ExamTeam> teams = [];
    try {
      final teamResponse = await api.teams(
        status: 'Active',
        branchId: currentBranchId,
      );
      teams = (teamResponse.data['data'] as List? ?? const [])
          .map((e) => ExamTeam.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}

    int? selectedBranchId = currentBranchId;
    int? selectedExamTypeId =
        (candidate.examTypeId == null || candidate.examTypeId == 0)
            ? null
            : candidate.examTypeId;
    int? selectedTeamId =
        (candidate.teamId == null || candidate.teamId == 0 || candidate.teamId == -1)
            ? null
            : candidate.teamId;
    String selectedStatus = candidate.status.toLowerCase() == 'absent'
        ? 'Not Completed'
        : (candidate.status.isEmpty ? 'Registered' : candidate.status);
    final nameCtrl = TextEditingController(text: candidate.name);
    final emailCtrl = TextEditingController(text: candidate.email);
    final phoneCtrl = TextEditingController(text: candidate.phone);
    final remarksCtrl = TextEditingController(text: candidate.remarks);
    final dateCtrl = TextEditingController(text: candidate.date);
    bool saving = false;

    List<ExamTeam> teamsForSelectedExam() => teams
        .where(
          (t) =>
              t.examTypeId == null ||
              selectedExamTypeId == null ||
              t.examTypeId == selectedExamTypeId,
        )
        .toList();

    List<DropdownMenuItem<int>> buildBranchItems() {
      final items = <DropdownMenuItem<int>>[];
      final seen = <int>{};
      for (final b in branches) {
        final id = int.tryParse('${b['id']}');
        if (id != null && seen.add(id)) {
          items.add(
            DropdownMenuItem<int>(
              value: id,
              child: Row(
                children: [
                  const Icon(
                    Icons.business_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${b['branch_name'] ?? b['name'] ?? 'Branch #$id'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
      if (selectedBranchId != null && seen.add(selectedBranchId!)) {
        items.add(
          DropdownMenuItem<int>(
            value: selectedBranchId!,
            child: Row(
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    candidate.branch.isNotEmpty
                        ? candidate.branch
                        : 'Branch #$selectedBranchId',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return items;
    }

    List<DropdownMenuItem<int>> buildExamTypeItems() {
      final items = <DropdownMenuItem<int>>[];
      final seen = <int>{};
      for (final e in examTypes) {
        final id = int.tryParse('${e['id']}');
        if (id != null && seen.add(id)) {
          items.add(
            DropdownMenuItem<int>(
              value: id,
              child: Row(
                children: [
                  const Icon(
                    Icons.school_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${e['name'] ?? 'Exam #$id'}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
      if (selectedExamTypeId != null && seen.add(selectedExamTypeId!)) {
        items.add(
          DropdownMenuItem<int>(
            value: selectedExamTypeId!,
            child: Row(
              children: [
                const Icon(
                  Icons.school_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    candidate.examType.isNotEmpty
                        ? candidate.examType
                        : 'Exam #$selectedExamTypeId',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return items;
    }

    List<DropdownMenuItem<int>> buildTeamItems() {
      final items = <DropdownMenuItem<int>>[];
      final seen = <int>{};

      seen.add(-1);
      items.add(
        const DropdownMenuItem<int>(
          value: -1,
          child: Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              SizedBox(width: 8),
              Expanded(child: Text('Not Assigned')),
            ],
          ),
        ),
      );

      for (final t in teamsForSelectedExam()) {
        if (seen.add(t.id)) {
          items.add(
            DropdownMenuItem<int>(
              value: t.id,
              child: Row(
                children: [
                  const Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (selectedTeamId != null && selectedTeamId! > 0 && seen.add(selectedTeamId!)) {
        final existingTeam =
            teams.where((t) => t.id == selectedTeamId).firstOrNull;
        final teamLabel = existingTeam?.name ??
            (candidate.teamName.isNotEmpty
                ? candidate.teamName
                : 'Assigned Team (ID #$selectedTeamId)');
        items.add(
          DropdownMenuItem<int>(
            value: selectedTeamId!,
            child: Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    teamLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return items;
    }

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
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
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.edit_rounded,
                          color: AppColors.primary,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Edit Candidate',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Update candidate details',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600,
                              ),
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
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _formSectionCard(
                    title: 'CANDIDATE DETAILS',
                    icon: Icons.badge_rounded,
                    color: const Color(0xFF7C3AED),
                    children: [
                      _label('Full Name *'),
                      const SizedBox(height: 6),
                      _field(
                        nameCtrl,
                        'Enter candidate name',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 14),
                      _label('Email'),
                      const SizedBox(height: 6),
                      _field(
                        emailCtrl,
                        'Candidate email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _label('Phone'),
                      const SizedBox(height: 6),
                      _field(
                        phoneCtrl,
                        'Candidate phone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _label('Remarks'),
                      const SizedBox(height: 6),
                      _field(
                        remarksCtrl,
                        'Add a note about this candidate...',
                        icon: Icons.notes_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _formSectionCard(
                    title: 'EXAM ASSIGNMENT',
                    icon: Icons.school_rounded,
                    color: AppColors.primary,
                    children: [
                      _label('Branch *'),
                      const SizedBox(height: 6),
                      _dropdown<int>(
                        value: selectedBranchId,
                        hint: 'Select branch',
                        items: buildBranchItems(),
                        onChanged: (val) async {
                          if (val == null) return;
                          setSheetState(() {
                            selectedBranchId = val;
                          });
                          try {
                            final res =
                                await api.teams(status: 'Active', branchId: val);
                            final newTeams = (res.data['data'] as List? ?? const [])
                                .map((e) =>
                                    ExamTeam.fromMap(Map<String, dynamic>.from(e)))
                                .toList();
                            setSheetState(() {
                              teams = newTeams;
                            });
                          } catch (_) {}
                        },
                      ),
                      const SizedBox(height: 14),
                      _label('Exam Type *'),
                      const SizedBox(height: 6),
                      _dropdown<int>(
                        value: selectedExamTypeId,
                        hint: 'Select exam type',
                        items: buildExamTypeItems(),
                        onChanged: (val) => setSheetState(() {
                          selectedExamTypeId = val;
                          if (selectedTeamId != null) {
                            final cur = teams
                                .where((t) => t.id == selectedTeamId)
                                .firstOrNull;
                            if (cur != null &&
                                cur.examTypeId != null &&
                                val != null &&
                                cur.examTypeId != val) {
                              selectedTeamId = null;
                            }
                          }
                        }),
                      ),
                      const SizedBox(height: 14),
                      _label('Team (Optional)'),
                      const SizedBox(height: 6),
                      _dropdown<int>(
                        value: (selectedTeamId != null && selectedTeamId! > 0)
                            ? selectedTeamId
                            : -1,
                        hint: 'Select team (optional)',
                        items: buildTeamItems(),
                        onChanged: (val) => setSheetState(
                          () => selectedTeamId =
                              (val == null || val == -1) ? null : val,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _label('Exam Date *'),
                      const SizedBox(height: 6),
                      TextField(
                        controller: dateCtrl,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Select date',
                          prefixIcon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 19,
                          ),
                          filled: true,
                          fillColor: Colors.white,
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
                          DateTime initial =
                              DateTime.tryParse(dateCtrl.text) ??
                              DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: initial,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            dateCtrl.text =
                                '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _formSectionCard(
                    title: 'STATUS',
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF7C3AED),
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _statusChip(
                            label: 'Registered',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF059669),
                            selected: selectedStatus == 'Registered',
                            onTap: () => setSheetState(
                              () => selectedStatus = 'Registered',
                            ),
                          ),
                          _statusChip(
                            label: 'Not Completed',
                            icon: Icons.person_off_rounded,
                            color: const Color(0xFFEA580C),
                            selected: selectedStatus == 'Not Completed',
                            onTap: () => setSheetState(
                              () => selectedStatus = 'Not Completed',
                            ),
                          ),
                          _statusChip(
                            label: 'Rescheduled',
                            icon: Icons.event_repeat_rounded,
                            color: const Color(0xFF7C3AED),
                            selected: selectedStatus == 'Rescheduled',
                            onTap: () => setSheetState(
                              () => selectedStatus = 'Rescheduled',
                            ),
                          ),
                          _statusChip(
                            label: 'Completed',
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF059669),
                            selected: selectedStatus == 'Completed',
                            onTap: () => setSheetState(
                              () => selectedStatus = 'Completed',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6C1FB0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        saving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Candidate name is required'),
                                    backgroundColor: AppColors.red,
                                  ),
                                );
                                return;
                              }
                              if (selectedBranchId == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select a branch'),
                                    backgroundColor: AppColors.red,
                                  ),
                                );
                                return;
                              }
                              if (selectedExamTypeId == null) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select an exam type'),
                                    backgroundColor: AppColors.red,
                                  ),
                                );
                                return;
                              }
                              if (dateCtrl.text.trim().isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select an exam date'),
                                    backgroundColor: AppColors.red,
                                  ),
                                );
                                return;
                              }
                              setSheetState(() => saving = true);
                              try {
                                final res = await api.updateCandidate(candidate.id, {
                                  'name': name,
                                  'email': emailCtrl.text.trim(),
                                  'phone': phoneCtrl.text.trim(),
                                  'branch_id': selectedBranchId,
                                  'exam_type_id': selectedExamTypeId,
                                  'team_id': selectedTeamId,
                                  'status': selectedStatus,
                                  'exam_date': dateCtrl.text.trim(),
                                  'remarks': remarksCtrl.text.trim(),
                                });
                                if (res.statusCode != null &&
                                    res.statusCode! >= 400) {
                                  final msg = res.data is Map &&
                                          res.data['message'] != null
                                      ? res.data['message']
                                      : 'Failed to update candidate (${res.statusCode})';
                                  throw Exception(msg);
                                }
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Candidate updated successfully',
                                    ),
                                    backgroundColor: AppColors.green,
                                  ),
                                );
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) reload();
                                });
                              } catch (e) {
                                if (ctx.mounted) {
                                  setSheetState(() => saving = false);
                                  String msg = e.toString();
                                  if (e is DioException &&
                                      e.response?.data is Map &&
                                      e.response?.data['message'] != null) {
                                    msg = e.response!.data['message'].toString();
                                  } else if (msg.startsWith('Exception: ')) {
                                    msg = msg.substring(11);
                                  }
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Unable to update candidate: $msg'),
                                      backgroundColor: AppColors.red,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtrl.dispose();
        emailCtrl.dispose();
        phoneCtrl.dispose();
        remarksCtrl.dispose();
        dateCtrl.dispose();
      });
    }
  }
}

// ================================================================
// TEAM CARD
// ================================================================

class _TeamCard extends StatelessWidget {
  final ExamTeam team;
  final VoidCallback onReport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TeamCard({
    required this.team,
    required this.onReport,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CardTint.fill(team.name),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CardTint.border(team.name)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EntityAvatar(
                seed: team.name,
                icon: Icons.groups_rounded,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      team.examTypeName.isEmpty
                          ? 'Any exam'
                          : team.examTypeName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: MenuTriggerIcon(
                  color: AvatarPalette.forSeed(team.name).first,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (v) {
                  if (v == 'report')
                    onReport();
                  else if (v == 'edit')
                    onEdit();
                  else if (v == 'delete')
                    onDelete();
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Team Report',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Edit',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFE11D48),
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE11D48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _teamMeta(
                Icons.location_on_outlined,
                team.location.isEmpty ? 'Location not set' : team.location,
              ),
              _teamMeta(
                Icons.phone_outlined,
                team.phone.isEmpty ? 'Phone not set' : team.phone,
              ),
              _teamMeta(
                Icons.people_alt_outlined,
                '${team.candidateCount} candidates',
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onReport,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Team Report — PDF / Excel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: Color(0xFFD8B4FE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamMeta(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 210),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// ================================================================
// EXAM TYPE CARD
// ================================================================

class _ExamTypeCard extends StatelessWidget {
  final ExamTypeItem examType;

  const _ExamTypeCard({required this.examType});

  @override
  Widget build(BuildContext context) {
    final isActive = examType.status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CardTint.fill(examType.name),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CardTint.border(examType.name)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isActive
                    ? AvatarPalette.forSeed(examType.name).first
                    : Colors.grey,
                width: 5,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              EntityAvatar(
                seed: examType.name,
                letter: examType.name.isNotEmpty
                    ? examType.name[0].toUpperCase()
                    : 'E',
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      examType.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${examType.language} • ${examType.description.isNotEmpty ? examType.description : "Exam"}',
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  examType.status,
                  style: TextStyle(
                    color: isActive ? AppColors.green : const Color(0xFFDC2626),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
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
// CANDIDATE CARD
// ================================================================

class _CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final Future<void> Function(int candidateId, String status) onStatusChanged;
  final Future<void> Function(Candidate candidate) onOpenDetails;
  final Future<void> Function(Candidate candidate) onEditRemarks;
  final Future<void> Function(Candidate candidate) onEditCandidate;
  final Future<void> Function(Candidate candidate) onDeleteCandidate;

  const _CandidateCard({
    required this.candidate,
    required this.onStatusChanged,
    required this.onOpenDetails,
    required this.onEditRemarks,
    required this.onEditCandidate,
    required this.onDeleteCandidate,
  });

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'registered':
        return AppColors.blue;
      case 'scheduled':
        return AppColors.primary;
      case 'completed':
        return AppColors.green;
      case 'cancelled':
        return AppColors.red;
      case 'absent':
      case 'not completed':
        return AppColors.orange;
      case 'rescheduled':
        return const Color(0xFF9A22C7);
      default:
        return AppColors.orange;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'registered':
        return const Color(0xFFDBEAFE);
      case 'scheduled':
        return const Color(0xFFEDE9FE);
      case 'completed':
        return const Color(0xFFDCFCE7);
      case 'cancelled':
        return const Color(0xFFFFE4E6);
      case 'absent':
        return const Color(0xFFEDE9FE);
      case 'rescheduled':
        return const Color(0xFFEDE9FE);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  Future<void> _showStatusMenu(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              const Text(
                'Update Candidate Status',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                candidate.name,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                title: const Text(
                  'Registered',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Candidate is registered for the exam'),
                onTap: () => Navigator.pop(ctx, 'Registered'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_off_rounded,
                    color: Color(0xFFEA580C),
                  ),
                ),
                title: const Text(
                  'Not Completed',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Candidate did not attend the exam'),
                onTap: () => Navigator.pop(ctx, 'Not Completed'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_repeat_rounded,
                    color: Color(0xFF9A22C7),
                  ),
                ),
                title: const Text(
                  'Rescheduled',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Candidate exam was moved to another date',
                ),
                onTap: () => Navigator.pop(ctx, 'Rescheduled'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF16A34A),
                  ),
                ),
                title: const Text(
                  'Completed',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('Candidate completed the exam'),
                onTap: () => Navigator.pop(ctx, 'Completed'),
              ),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      await onStatusChanged(candidate.id, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = candidate.status.isEmpty ? 'Registered' : candidate.status;
    final canUpdate = true;

    return GestureDetector(
      onTap: () => onOpenDetails(candidate),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CardTint.fill(candidate.name),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CardTint.border(candidate.name)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            EntityAvatar(
              seed: candidate.name,
              letter: candidate.name.isNotEmpty
                  ? candidate.name[0].toUpperCase()
                  : '?',
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  if (candidate.examType.isNotEmpty)
                    Text(
                      candidate.examType,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 12,
                      ),
                    ),
                  if (candidate.teamName.isNotEmpty)
                    Text(
                      'Team: ${candidate.teamName}',
                      style: const TextStyle(
                        color: Color(0xFF9A22C7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (candidate.branch.isNotEmpty) candidate.branch,
                      if (candidate.date.isNotEmpty) candidate.date,
                    ].join(' • '),
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: canUpdate
                            ? () => _showStatusMenu(context)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              status,
                              style: TextStyle(
                                color: _statusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (canUpdate) ...[
                              const SizedBox(width: 3),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 15,
                                color: _statusColor(status),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => onEditRemarks(candidate),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notes_rounded,
                              size: 14,
                              color: candidate.remarks.isEmpty
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Remarks',
                              style: TextStyle(
                                color: candidate.remarks.isEmpty
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFFEA580C),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.edit_rounded,
                              size: 12,
                              color: candidate.remarks.isEmpty
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFFEA580C),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (candidate.remarks.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      candidate.remarks,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      color: const Color(0xFFF3E8FF),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onEditCandidate(candidate),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => onDeleteCandidate(candidate),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(7),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 15,
                            color: AppColors.red,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: _statusColor(status),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CandidateDetailsScreen extends StatefulWidget {
  final Candidate candidate;
  const CandidateDetailsScreen({super.key, required this.candidate});

  @override
  State<CandidateDetailsScreen> createState() => _CandidateDetailsScreenState();
}

class _CandidateDetailsScreenState extends State<CandidateDetailsScreen> {
  final api = DioClient();
  late Candidate candidate;
  late TextEditingController remarksCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    candidate = widget.candidate;
    remarksCtrl = TextEditingController(text: candidate.remarks);
    _loadCandidateDetails();
  }

  Future<void> _loadCandidateDetails() async {
    try {
      final res = await api.candidateDetails(candidate.id);
      final data = Map<String, dynamic>.from(res.data['data'] ?? {});
      if (data.isNotEmpty && mounted) {
        setState(() {
          candidate = Candidate.fromMap(data);
          if (remarksCtrl.text.isEmpty && candidate.remarks.isNotEmpty) {
            remarksCtrl.text = candidate.remarks;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    remarksCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'registered':
        return AppColors.blue;
      case 'scheduled':
        return AppColors.primary;
      case 'completed':
        return AppColors.green;
      case 'cancelled':
        return AppColors.red;
      case 'absent':
      case 'not completed':
        return AppColors.orange;
      case 'rescheduled':
        return const Color(0xFF9A22C7);
      default:
        return AppColors.orange;
    }
  }

  String _buildFullImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final relative = path.startsWith('/') ? path : '/$path';
    return '$base$relative';
  }

  void _showFullImageDialog(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0E3FA),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.image_rounded,
                          size: 16,
                          color: Color(0xFF6C1FB0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, st) => Container(
                        height: 180,
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: const Text('Failed to load image'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0x22000000),
                  child: Icon(Icons.close_rounded, color: Colors.black87, size: 18),
                ),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassportImageCard(String title, String imagePath) {
    final fullUrl = _buildFullImageUrl(imagePath);
    final hasImage = fullUrl.isNotEmpty;

    return Expanded(
      child: InkWell(
        onTap: hasImage
            ? () => _showFullImageDialog(context, fullUrl, title)
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasImage ? Icons.image_rounded : Icons.broken_image_rounded,
                    size: 16,
                    color: hasImage ? const Color(0xFF6C1FB0) : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasImage)
                    const Icon(
                      Icons.zoom_in_rounded,
                      size: 16,
                      color: Color(0xFF6C1FB0),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: hasImage
                    ? AspectRatio(
                        aspectRatio: 16 / 10,
                        child: Image.network(
                          fullUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: const Color(0xFFF3F4F6),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (ctx, err, stack) => Container(
                            color: const Color(0xFFF3F4F6),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline_rounded, color: Colors.grey, size: 20),
                                SizedBox(height: 4),
                                Text(
                                  'Image unavailable',
                                  style: TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 90,
                        color: const Color(0xFFF3F4F6),
                        alignment: Alignment.center,
                        child: const Text(
                          'No image uploaded',
                          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF0E3FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF6C1FB0)),
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
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
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
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0E3FA),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: const Color(0xFF6C1FB0)),
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF6B7280),
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ...children,
        ],
      ),
    );
  }

  Future<void> _saveRemarks() async {
    setState(() => saving = true);
    try {
      final r = await api.updateCandidate(candidate.id, {
        'remarks': remarksCtrl.text.trim(),
      });
      final data = Map<String, dynamic>.from(r.data['data'] ?? {});
      if (data.isNotEmpty) {
        candidate = Candidate.fromMap(data);
        remarksCtrl.text = candidate.remarks;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remarks saved successfully.'),
          backgroundColor: AppColors.green,
        ),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to save remarks: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = candidate.status.isEmpty ? 'Registered' : candidate.status;
    final statusColor = _statusColor(status);
    final hasImages = candidate.passportFrontImage.isNotEmpty || candidate.passportLastImage.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 0,
        toolbarHeight: 64,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text(
          'Candidate Details',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6C1FB0), Color(0xFF9A22C7), Color(0xFFE0189E)],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF1E6), Color(0xFFFFFFFF)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD7B5)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      candidate.name.isNotEmpty
                          ? candidate.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 25,
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
                        candidate.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        candidate.examType.isEmpty
                            ? 'Exam candidate'
                            : candidate.examType,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (candidate.teamName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Team: ${candidate.teamName}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6C1FB0),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 1. Personal Information Section
          _section('PERSONAL INFORMATION', Icons.person_rounded, [
            _infoRow(
              Icons.badge_rounded,
              'Register Number / Roll No',
              candidate.registerNumber,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(Icons.email_outlined, 'Email', candidate.email),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(Icons.phone_outlined, 'Phone', candidate.phone),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.cake_outlined,
              'Date of Birth',
              candidate.passportDob,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.wc_rounded,
              'Gender',
              candidate.passportGender,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.public_rounded,
              'Nationality',
              candidate.passportNationality,
            ),
          ]),

          // 2. Exam Information Section
          _section('EXAM INFORMATION', Icons.school_rounded, [
            _infoRow(Icons.menu_book_rounded, 'Exam Type', candidate.examType),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.account_tree_rounded,
              'Branch / Centre',
              candidate.branch,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(Icons.groups_rounded, 'Team', candidate.teamName),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(Icons.calendar_month_rounded, 'Exam Date', candidate.date),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(Icons.flag_rounded, 'Current Status', status),
          ]),

          // 3. Passport Information Section (Entered / Groq OCR Extracted)
          _section('PASSPORT INFORMATION', Icons.flight_takeoff_rounded, [
            _infoRow(
              Icons.credit_card_rounded,
              'Passport Number',
              candidate.passportNumber,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.badge_outlined,
              'Full Name on Passport',
              candidate.passportFullName,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.calendar_today_rounded,
              'Date of Birth',
              candidate.passportDob,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.wc_rounded,
              'Gender',
              candidate.passportGender,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.flag_outlined,
              'Nationality',
              candidate.passportNationality,
            ),
            if (candidate.placeOfBirth.isNotEmpty) ...[
              const Divider(height: 1, color: Color(0xFFF3F4F6)),
              _infoRow(
                Icons.location_city_rounded,
                'Place of Birth',
                candidate.placeOfBirth,
              ),
            ],
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.event_available_rounded,
              'Date of Issue',
              candidate.passportIssueDate,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.event_busy_rounded,
              'Date of Expiry',
              candidate.passportExpiryDate,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.document_scanner_rounded,
              'Passport Scan Date (IST)',
              candidate.passportScanDate,
            ),
          ]),

          // 4. Address Details Section
          _section('ADDRESS INFORMATION', Icons.home_rounded, [
            _infoRow(
              Icons.signpost_rounded,
              'Address Line 1',
              candidate.addressLine1,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.apartment_rounded,
              'Address Line 2',
              candidate.addressLine2,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.location_city_rounded,
              'City',
              candidate.city,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.map_rounded,
              'State / Province',
              candidate.state,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.pin_drop_rounded,
              'Postal Code / PIN',
              candidate.postalCode,
            ),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            _infoRow(
              Icons.public_rounded,
              'Country',
              candidate.country,
            ),
          ]),

          // 5. Scanned Passport Images Section
          _section('SCANNED PASSPORT IMAGES', Icons.photo_library_rounded, [
            if (hasImages) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  _buildPassportImageCard('Front Page', candidate.passportFrontImage),
                  const SizedBox(width: 12),
                  _buildPassportImageCard('Last / Address Page', candidate.passportLastImage),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
                    SizedBox(width: 8),
                    Text(
                      'No scanned passport images attached.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ]),

          // 6. Remarks Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
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
                    const Icon(
                      Icons.sticky_note_2_rounded,
                      size: 20,
                      color: Color(0xFF6C1FB0),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Remarks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${remarksCtrl.text.length}/500',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 6,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Add or edit remarks about this candidate...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: const Color(0xFFF7F5FD),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(
                        color: Color(0xFF9A22C7),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _saveRemarks,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6C1FB0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      saving ? 'Saving...' : 'Save Remarks',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}