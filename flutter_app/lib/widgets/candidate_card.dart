import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../config/api_config.dart';
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
