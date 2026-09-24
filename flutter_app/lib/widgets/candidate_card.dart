import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';

// ================================================================
// REUSABLE CANDIDATE CARD
// ================================================================

class CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final Future<void> Function(int candidateId, String status) onStatusChanged;
  final Future<void> Function(Candidate candidate) onOpenDetails;
  final Future<void> Function(Candidate candidate) onEditRemarks;
  final Future<void> Function(Candidate candidate) onEditCandidate;
  final Future<void> Function(Candidate candidate) onDeleteCandidate;

  const CandidateCard({
    super.key,
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
      case 'not completed':
        return const Color(0xFFFEF3C7);
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
                        onTap: () => _showStatusMenu(context),
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
                            const SizedBox(width: 3),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: _statusColor(status),
                            ),
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

// ================================================================
// CANDIDATE DETAILS SCREEN
// ================================================================

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
          _section('PERSONAL DETAILS', Icons.person_rounded, [
            _infoRow(
              Icons.badge_rounded,
              'Register Number / ID',
              candidate.registerNumber.isNotEmpty
                  ? candidate.registerNumber
                  : '#${candidate.id}',
            ),
            _infoRow(
              Icons.email_rounded,
              'Email Address',
              candidate.email.isNotEmpty ? candidate.email : 'Not provided',
            ),
            _infoRow(
              Icons.phone_rounded,
              'Phone Number',
              candidate.phone.isNotEmpty ? candidate.phone : 'Not provided',
            ),
          ]),
          _section('EXAM DETAILS', Icons.school_rounded, [
            _infoRow(
              Icons.domain_rounded,
              'Branch',
              candidate.branch.isNotEmpty ? candidate.branch : 'Main Branch',
            ),
            _infoRow(
              Icons.menu_book_rounded,
              'Exam Type',
              candidate.examType.isNotEmpty ? candidate.examType : 'Standard Exam',
            ),
            _infoRow(
              Icons.groups_rounded,
              'Exam Team',
              candidate.teamName.isNotEmpty ? candidate.teamName : 'Not Assigned',
            ),
            _infoRow(
              Icons.calendar_today_rounded,
              'Exam Date',
              candidate.date.isNotEmpty ? candidate.date : 'Not scheduled',
            ),
            _infoRow(
              Icons.check_circle_outline_rounded,
              'Status',
              status,
            ),
          ]),
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Remarks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF374151),
                      ),
                    ),
                    Text(
                      '${remarksCtrl.text.length}/500',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: remarksCtrl,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Add or edit remarks about this candidate...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _saveRemarks,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
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
