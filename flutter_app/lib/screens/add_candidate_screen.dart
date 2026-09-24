import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../models.dart';
import '../providers/branch_context.dart';
import '../services/dio_client.dart';

class AddCandidateScreen extends StatefulWidget {
  final int? initialBranchId;

  const AddCandidateScreen({super.key, this.initialBranchId});

  @override
  State<AddCandidateScreen> createState() => _AddCandidateScreenState();
}

class _AddCandidateScreenState extends State<AddCandidateScreen> {
  final api = DioClient();
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final remarksCtrl = TextEditingController();
  final dateCtrl = TextEditingController();

  // Dropdown Selections
  int? selectedBranchId;
  int? selectedExamTypeId;
  int? selectedTeamId;
  String selectedStatus = 'Registered';

  // Lookups data
  List<Map<String, dynamic>> branchesList = [];
  List<Map<String, dynamic>> examTypesList = [];
  List<ExamTeam> teamsList = [];
  bool loadingLookups = true;
  bool isSaving = false;

  // Existing Candidate Check
  Timer? _debounceTimer;
  bool isCheckingName = false;
  Candidate? matchedCandidate;

  @override
  void initState() {
    super.initState();
    // Default exam date to today
    final now = DateTime.now();
    dateCtrl.text =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    _loadData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    remarksCtrl.dispose();
    dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final branchCtx = context.read<BranchContext>();
    await branchCtx.ensureLoaded();

    try {
      final brFuture = api.branches();
      final etFuture = api.examTypes();
      final tmFuture = api.teams(status: 'Active');

      final results = await Future.wait([brFuture, etFuture, tmFuture]);

      final brData = (results[0].data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final etData = (results[1].data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final tmData = (results[2].data['data'] as List? ?? [])
          .map((e) => ExamTeam.fromMap(Map<String, dynamic>.from(e)))
          .toList();

      if (!mounted) return;

      setState(() {
        branchesList = brData;
        examTypesList = etData;
        teamsList = tmData;

        // Set initial branch from prop or context or first available
        selectedBranchId = widget.initialBranchId ??
            branchCtx.selectedBranchId ??
            (branchesList.isNotEmpty ? branchesList.first['id'] as int? : null);

        if (examTypesList.isNotEmpty) {
          selectedExamTypeId = examTypesList.first['id'] as int?;
        }

        loadingLookups = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => loadingLookups = false);
      }
    }
  }

  // Debounced search for candidate name verification
  void _onNameChanged(String val) {
    _debounceTimer?.cancel();
    final trimmed = val.trim();

    if (trimmed.length < 2) {
      if (matchedCandidate != null || isCheckingName) {
        setState(() {
          matchedCandidate = null;
          isCheckingName = false;
        });
      }
      return;
    }

    setState(() => isCheckingName = true);

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await api.candidates(q: trimmed);
        final list = (res.data['data'] as List? ?? [])
            .map((e) => Candidate.fromMap(Map<String, dynamic>.from(e)))
            .toList();

        if (!mounted) return;
        if (nameCtrl.text.trim() != trimmed) return; // Typed further

        Candidate? match;
        final lower = trimmed.toLowerCase();

        // Exact match first
        for (final c in list) {
          if (c.name.trim().toLowerCase() == lower) {
            match = c;
            break;
          }
        }
        // Partial match fallback
        match ??= list.where((c) => c.name.toLowerCase().contains(lower)).firstOrNull;

        setState(() {
          matchedCandidate = match;
          isCheckingName = false;
        });
      } catch (_) {
        if (mounted) {
          setState(() => isCheckingName = false);
        }
      }
    });
  }

  String _formatDateDisplay(String raw) {
    if (raw.trim().isEmpty) return 'Not scheduled';
    final parts = raw.trim().split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      if (parts[0].length == 4) {
        // YYYY-MM-DD -> DD-MM-YYYY
        return '${parts[2].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[0]}';
      } else if (parts[2].length == 4) {
        // DD-MM-YYYY
        return '${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}-${parts[2]}';
      }
    }
    return raw;
  }

  List<ExamTeam> _filteredTeams() {
    return teamsList.where((t) {
      return t.examTypeId == null ||
          selectedExamTypeId == null ||
          t.examTypeId == selectedExamTypeId;
    }).toList();
  }

  Future<void> _submitCandidate() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidate name is required'),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await api.createCandidate({
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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Candidate added successfully!'),
          backgroundColor: AppColors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add candidate: $e'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTeams = _filteredTeams();

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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Candidate',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: .2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Register a new exam candidate',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: AppBarStyle.gradientDecoration(),
        ),
      ),
      body: loadingLookups
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  // ============================================================
                  // SECTION 1: CANDIDATE INFORMATION
                  // ============================================================
                  _buildCard(
                    title: 'CANDIDATE INFORMATION',
                    icon: Icons.person_rounded,
                    accentColor: AppColors.primary,
                    children: [
                      // Full Name
                      _buildLabel('Full Name *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        onChanged: _onNameChanged,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          hintText: 'Enter candidate name',
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                          ),
                          suffixIcon: isCheckingName
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),

                      // Existing Candidate Verification Suggestion Banner
                      if (matchedCandidate != null) ...[
                        const SizedBox(height: 8),
                        _buildExistingCandidateBanner(matchedCandidate!),
                      ],

                      const SizedBox(height: 14),

                      // Email & Phone in responsive row or column
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Email'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    hintText: 'name@example.com',
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      size: 19,
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
                                _buildLabel('Phone'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: phoneCtrl,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    hintText: 'Phone number',
                                    prefixIcon: Icon(
                                      Icons.phone_outlined,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ============================================================
                  // SECTION 2: EXAM & BRANCH ASSIGNMENT
                  // ============================================================
                  _buildCard(
                    title: 'EXAM & BRANCH ASSIGNMENT',
                    icon: Icons.school_rounded,
                    accentColor: const Color(0xFF059669),
                    children: [
                      // Branch (Read-only — locked to dashboard-selected branch)
                      _buildLabel('Branch'),
                      const SizedBox(height: 6),
                      Builder(builder: (context) {
                        final branchCtx = context.read<BranchContext>();
                        final lockedBranch = branchesList.firstWhere(
                          (b) => b['id'] == selectedBranchId,
                          orElse: () => {},
                        );
                        final branchName = lockedBranch.isNotEmpty
                            ? '${lockedBranch['branch_name'] ?? 'Selected Branch'}'
                            : (branchCtx.selectedBranchName);
                        return Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_rounded,
                                size: 18,
                                color: Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  branchName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                              const Text(
                                'Auto-selected',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF9CA3AF),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 14),

                      // Exam Type
                      _buildLabel('Exam Type'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedExamTypeId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.menu_book_rounded,
                            size: 20,
                          ),
                        ),
                        hint: const Text('Select exam type'),
                        items: examTypesList.map((e) {
                          return DropdownMenuItem<int>(
                            value: e['id'],
                            child: Text(
                              '${e['name'] ?? ''}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            selectedExamTypeId = val;
                            selectedTeamId = null;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      // Team
                      _buildLabel('Team (Optional)'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: selectedTeamId ?? -1,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.groups_rounded,
                            size: 20,
                          ),
                        ),
                        hint: const Text('Select team (optional)'),
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
                          ...filteredTeams.map((t) {
                            return DropdownMenuItem<int>(
                              value: t.id,
                              child: Text(
                                t.name,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            selectedTeamId = (val == null || val == -1) ? null : val;
                          });
                        },
                      ),

                      const SizedBox(height: 14),

                      // Exam Date
                      _buildLabel('Exam Date'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: dateCtrl,
                        readOnly: true,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: 'Select date (YYYY-MM-DD)',
                          prefixIcon: Icon(
                            Icons.calendar_today_rounded,
                            size: 19,
                          ),
                          suffixIcon: Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 24,
                          ),
                        ),
                        onTap: () async {
                          final now = DateTime.now();
                          final initial = DateTime.tryParse(dateCtrl.text) ?? now;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(1900),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.primary,
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: AppColors.textDark,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() {
                              dateCtrl.text =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ============================================================
                  // SECTION 3: STATUS & REMARKS
                  // ============================================================
                  _buildCard(
                    title: 'STATUS & REMARKS',
                    icon: Icons.flag_rounded,
                    accentColor: const Color(0xFF7C3AED),
                    children: [
                      // Status Selector Chips
                      _buildLabel('Initial Status'),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatusOption(
                              label: 'Registered',
                              icon: Icons.check_circle_rounded,
                              activeColor: const Color(0xFF2563EB),
                              activeBg: const Color(0xFFDBEAFE),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusOption(
                              label: 'Not Completed',
                              icon: Icons.person_off_rounded,
                              activeColor: const Color(0xFFEA580C),
                              activeBg: const Color(0xFFFFEDD5),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusOption(
                              label: 'Rescheduled',
                              icon: Icons.event_repeat_rounded,
                              activeColor: const Color(0xFF7C3AED),
                              activeBg: const Color(0xFFEDE9FE),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Remarks
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Remarks / Notes'),
                          Text(
                            '${remarksCtrl.text.length}/500',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: remarksCtrl,
                        maxLines: 3,
                        maxLength: 500,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'Add any remarks, rescheduled notes, or special instructions...',
                          alignLabelWithHint: true,
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      // Sticky Bottom Submit Button
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: brandLinearGradient(),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(.30),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _submitCandidate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.person_add_rounded, size: 20),
                label: Text(
                  isSaving ? 'Adding Candidate...' : 'Add Candidate',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EXISTING CANDIDATE VERIFICATION SUGGESTION BANNER
  // ============================================================
  Widget _buildExistingCandidateBanner(Candidate candidate) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber 50
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2), // Amber 200
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7), // Amber 100
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: Color(0xFFD97706), // Amber 600
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Existing candidate found',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB45309), // Amber 700
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  candidate.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Previous Exam Date: ${_formatDateDisplay(candidate.date)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B5563),
                  ),
                ),
                if (candidate.branch.isNotEmpty || candidate.examType.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (candidate.branch.isNotEmpty) candidate.branch,
                      if (candidate.examType.isNotEmpty) candidate.examType,
                    ].join(' • '),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS CHIP WIDGET
  // ============================================================
  Widget _buildStatusOption({
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
  }) {
    final isSelected = selectedStatus == label;

    return InkWell(
      onTap: () => setState(() => selectedStatus = label),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? activeColor : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD CONTAINER
  // ============================================================
  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color accentColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tint, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: accentColor,
                  letterSpacing: .4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        color: Color(0xFF374151),
      ),
    );
  }
}
