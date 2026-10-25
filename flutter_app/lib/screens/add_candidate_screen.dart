import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  // Passport & Address Form Controllers
  final passportNumberCtrl = TextEditingController();
  final passportFullNameCtrl = TextEditingController();
  final passportDobCtrl = TextEditingController();
  final passportGenderCtrl = TextEditingController();
  final passportNationalityCtrl = TextEditingController();
  final passportIssueDateCtrl = TextEditingController();
  final passportExpiryDateCtrl = TextEditingController();
  final addressLine1Ctrl = TextEditingController();
  final addressLine2Ctrl = TextEditingController();
  final cityCtrl = TextEditingController();
  final stateCtrl = TextEditingController();
  final postalCodeCtrl = TextEditingController();
  final countryCtrl = TextEditingController();
  final scanDateCtrl = TextEditingController();

  // Passport Camera Workflow State (12-step flow)
  final ImagePicker _picker = ImagePicker();
  String? _tempFrontPath;
  XFile? _tempFrontXFile;
  String? _frontImagePath;
  XFile? _frontXFile;
  bool _frontImageConfirmed = false;

  String? _tempLastPath;
  XFile? _tempLastXFile;
  String? _lastImagePath;
  XFile? _lastXFile;
  bool _lastImageConfirmed = false;

  bool isScanningPassport = false;
  String? frontImageUrl;
  String? lastImageUrl;
  String? passportScanStatusMessage;
  bool passportExtractionSuccess = false;

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
  bool loadingTeams = false;
  String? teamsError;
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
    passportNumberCtrl.dispose();
    passportFullNameCtrl.dispose();
    passportDobCtrl.dispose();
    passportGenderCtrl.dispose();
    passportNationalityCtrl.dispose();
    passportIssueDateCtrl.dispose();
    passportExpiryDateCtrl.dispose();
    addressLine1Ctrl.dispose();
    addressLine2Ctrl.dispose();
    cityCtrl.dispose();
    stateCtrl.dispose();
    postalCodeCtrl.dispose();
    countryCtrl.dispose();
    scanDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    if (!mounted) return;
    setState(() {
      loadingTeams = true;
      teamsError = null;
    });
    try {
      final res = await api.teams(status: 'Active', branchId: selectedBranchId);
      final tmData = (res.data['data'] as List? ?? [])
          .map((e) => ExamTeam.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      if (!mounted) return;
      setState(() {
        teamsList = tmData;
        loadingTeams = false;
        if (selectedTeamId != null &&
            !teamsList.any((t) => t.id == selectedTeamId)) {
          selectedTeamId = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loadingTeams = false;
        teamsError = 'Failed to load teams: $e';
      });
    }
  }

  Future<void> _loadData() async {
    final branchCtx = context.read<BranchContext>();
    await branchCtx.ensureLoaded();

    try {
      final brFuture = api.branches();
      final etFuture = api.examTypes();

      final results = await Future.wait([brFuture, etFuture]);

      final brData = (results[0].data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final etData = (results[1].data['data'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;

      setState(() {
        branchesList = brData;
        examTypesList = etData;

        // Set initial branch from prop or context or first available
        selectedBranchId = widget.initialBranchId ??
            branchCtx.selectedBranchId ??
            (branchesList.isNotEmpty ? branchesList.first['id'] as int? : null);

        if (examTypesList.isNotEmpty) {
          selectedExamTypeId = examTypesList.first['id'] as int?;
        }

        loadingLookups = false;
      });

      // Load teams for selected branch
      await _loadTeams();
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
      final matchesBranch = t.branchId == null ||
          selectedBranchId == null ||
          t.branchId == selectedBranchId;
      final matchesExam = t.examTypeId == null ||
          selectedExamTypeId == null ||
          t.examTypeId == selectedExamTypeId;
      return matchesBranch && matchesExam;
    }).toList();
  }

  Future<void> _showCreateTeamDialog() async {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    int? dialogExamTypeId = selectedExamTypeId;
    bool savingTeam = false;

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
                      'Create Team',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildLabel('Team Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. CELPIP Partner Team',
                    prefixIcon: Icon(Icons.groups_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                _buildLabel('Location'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Team location / service area',
                    prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                _buildLabel('Phone Number'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'Team contact number',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 14),
                _buildLabel('Exam Type'),
                const SizedBox(height: 6),
                DropdownButtonFormField<int>(
                  value: dialogExamTypeId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.school_outlined, size: 20),
                  ),
                  hint: const Text('Select exam type'),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Any exam'),
                    ),
                    ...examTypesList.map((e) {
                      final id = int.tryParse('${e['id']}');
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text('${e['name'] ?? ''}'),
                      );
                    }),
                  ],
                  onChanged: (v) => setSheetState(() => dialogExamTypeId = v),
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
                    onPressed: savingTeam
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Team name is required'),
                                ),
                              );
                              return;
                            }
                            setSheetState(() => savingTeam = true);
                            try {
                              final resp = await api.createTeam({
                                'name': name,
                                'location': locationCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'branch_id': selectedBranchId,
                                'exam_type_id': dialogExamTypeId,
                                'status': 'Active',
                              });
                              final newTeamData = resp.data['data'] as Map<String, dynamic>?;
                              final newId = newTeamData != null ? int.tryParse('${newTeamData['id']}') : null;
                              if (ctx.mounted) Navigator.pop(ctx);
                              await _loadTeams();
                              if (mounted) {
                                setState(() {
                                  if (newId != null) {
                                    selectedTeamId = newId;
                                  }
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Team "$name" created successfully!'),
                                    backgroundColor: AppColors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              setSheetState(() => savingTeam = false);
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('Error creating team: $e')),
                                );
                              }
                            }
                          },
                    icon: savingTeam
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(savingTeam ? 'Creating...' : 'Create Team'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PASSPORT CAMERA CAPTURE WORKFLOW (STEPS 1-7)
  // ============================================================
  Future<void> _captureFrontPage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _tempFrontPath = photo.path;
          _tempFrontXFile = photo;
          _frontImageConfirmed = false;
        });
      }
    } catch (e) {
      _showError('Camera error: Unable to capture front page ($e)');
    }
  }

  void _confirmFrontPage() {
    if (_tempFrontPath != null) {
      setState(() {
        _frontImagePath = _tempFrontPath;
        _frontXFile = _tempFrontXFile;
        _frontImageConfirmed = true;
      });
    }
  }

  void _retakeFrontPage() {
    setState(() {
      _tempFrontPath = null;
      _tempFrontXFile = null;
      _frontImagePath = null;
      _frontXFile = null;
      _frontImageConfirmed = false;
      passportExtractionSuccess = false;
    });
    _captureFrontPage();
  }

  Future<void> _captureLastPage() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _tempLastPath = photo.path;
          _tempLastXFile = photo;
          _lastImageConfirmed = false;
        });
      }
    } catch (e) {
      _showError('Camera error: Unable to capture last page ($e)');
    }
  }

  void _confirmLastPage() {
    if (_tempLastPath != null) {
      setState(() {
        _lastImagePath = _tempLastPath;
        _lastXFile = _tempLastXFile;
        _lastImageConfirmed = true;
      });
    }
  }

  void _retakeLastPage() {
    setState(() {
      _tempLastPath = null;
      _tempLastXFile = null;
      _lastImagePath = null;
      _lastXFile = null;
      _lastImageConfirmed = false;
      passportExtractionSuccess = false;
    });
    _captureLastPage();
  }

  // ============================================================
  // GROQ AI EXTRACTION (STEPS 8-10)
  // ============================================================
  Future<void> _scanPassportWithGroq() async {
    if (_frontImagePath == null || _lastImagePath == null) {
      _showError('Please capture and confirm both passport front and last pages.');
      return;
    }

    setState(() {
      isScanningPassport = true;
      passportScanStatusMessage = 'Uploading passport pages & extracting information via Groq AI...';
    });

    try {
      final frontBytes = _frontXFile != null
          ? await _frontXFile!.readAsBytes()
          : (kIsWeb ? <int>[] : await File(_frontImagePath!).readAsBytes());
      final lastBytes = _lastXFile != null
          ? await _lastXFile!.readAsBytes()
          : (kIsWeb ? <int>[] : await File(_lastImagePath!).readAsBytes());

      final res = await api.scanPassport(
        frontBytes: frontBytes,
        frontFilename: _frontXFile?.name.isNotEmpty == true ? _frontXFile!.name : 'front_page.jpg',
        lastBytes: lastBytes,
        lastFilename: _lastXFile?.name.isNotEmpty == true ? _lastXFile!.name : 'last_page.jpg',
      );

      final data = res.data;
      final bool success = data['success'] == true;
      final payload = Map<String, dynamic>.from(data['data'] ?? {});

      if (!mounted) return;

      if (success) {
        setState(() {
          // Auto-populate extracted passport details without overwriting manual selections
          if ((payload['passport_full_name'] ?? '').toString().trim().isNotEmpty) {
            final extractedName = payload['passport_full_name'].toString().trim();
            passportFullNameCtrl.text = extractedName;
            if (nameCtrl.text.trim().isEmpty) {
              nameCtrl.text = extractedName;
            }
          }
          if ((payload['passport_number'] ?? '').toString().trim().isNotEmpty) {
            passportNumberCtrl.text = payload['passport_number'].toString().trim();
          }
          if ((payload['passport_dob'] ?? '').toString().trim().isNotEmpty) {
            passportDobCtrl.text = payload['passport_dob'].toString().trim();
          }
          if ((payload['passport_gender'] ?? '').toString().trim().isNotEmpty) {
            passportGenderCtrl.text = payload['passport_gender'].toString().trim();
          }
          if ((payload['passport_nationality'] ?? '').toString().trim().isNotEmpty) {
            passportNationalityCtrl.text = payload['passport_nationality'].toString().trim();
          }
          if ((payload['passport_issue_date'] ?? '').toString().trim().isNotEmpty) {
            passportIssueDateCtrl.text = payload['passport_issue_date'].toString().trim();
          }
          if ((payload['passport_expiry_date'] ?? '').toString().trim().isNotEmpty) {
            passportExpiryDateCtrl.text = payload['passport_expiry_date'].toString().trim();
          }

          // Address details
          if ((payload['address_line_1'] ?? '').toString().trim().isNotEmpty) {
            addressLine1Ctrl.text = payload['address_line_1'].toString().trim();
          }
          if ((payload['address_line_2'] ?? '').toString().trim().isNotEmpty) {
            addressLine2Ctrl.text = payload['address_line_2'].toString().trim();
          }
          if ((payload['city'] ?? '').toString().trim().isNotEmpty) {
            cityCtrl.text = payload['city'].toString().trim();
          }
          if ((payload['state'] ?? '').toString().trim().isNotEmpty) {
            stateCtrl.text = payload['state'].toString().trim();
          }
          if ((payload['postal_code'] ?? '').toString().trim().isNotEmpty) {
            postalCodeCtrl.text = payload['postal_code'].toString().trim();
          }
          if ((payload['country'] ?? '').toString().trim().isNotEmpty) {
            countryCtrl.text = payload['country'].toString().trim();
          }
          if ((payload['passport_scan_date'] ?? '').toString().trim().isNotEmpty) {
            scanDateCtrl.text = payload['passport_scan_date'].toString().trim();
          }

          frontImageUrl = payload['passport_front_image'] as String?;
          lastImageUrl = payload['passport_last_image'] as String?;
          passportExtractionSuccess = true;
          passportScanStatusMessage = 'Passport information extracted successfully! Review fields below.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Passport extracted! Please review and verify details.'),
            backgroundColor: AppColors.green,
          ),
        );
      } else {
        final msg = data['message'] ?? 'Could not extract all details. You can enter them manually.';
        setState(() {
          passportExtractionSuccess = false;
          passportScanStatusMessage = msg;
          if ((payload['passport_scan_date'] ?? '').toString().trim().isNotEmpty) {
            scanDateCtrl.text = payload['passport_scan_date'].toString().trim();
          }
          frontImageUrl = payload['passport_front_image'] as String?;
          lastImageUrl = payload['passport_last_image'] as String?;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        passportScanStatusMessage = 'Extraction error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanning failed: $e. You can continue manually.'),
          backgroundColor: AppColors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isScanningPassport = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.red),
    );
  }

  Future<void> _submitCandidate() async {
    if (nameCtrl.text.trim().isEmpty) {
      _showError('Candidate name is required');
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
        'team_id': (selectedTeamId == null || selectedTeamId == -1)
            ? null
            : selectedTeamId,
        'status': selectedStatus,
        'exam_date': dateCtrl.text.trim(),
        'remarks': remarksCtrl.text.trim(),
        // Passport and address fields
        'passport_number': passportNumberCtrl.text.trim(),
        'passport_full_name': passportFullNameCtrl.text.trim(),
        'passport_dob': passportDobCtrl.text.trim(),
        'passport_gender': passportGenderCtrl.text.trim(),
        'passport_nationality': passportNationalityCtrl.text.trim(),
        'passport_issue_date': passportIssueDateCtrl.text.trim(),
        'passport_expiry_date': passportExpiryDateCtrl.text.trim(),
        'address_line_1': addressLine1Ctrl.text.trim(),
        'address_line_2': addressLine2Ctrl.text.trim(),
        'city': cityCtrl.text.trim(),
        'state': stateCtrl.text.trim(),
        'postal_code': postalCodeCtrl.text.trim(),
        'country': countryCtrl.text.trim(),
        'passport_scan_date': scanDateCtrl.text.trim(),
        'passport_front_image': frontImageUrl ?? '',
        'passport_last_image': lastImageUrl ?? '',
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
      _showError('Failed to add candidate: $e');
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
                  // SECTION 0: AI PASSPORT SCANNER (GROQ AI VISION)
                  // ============================================================
                  _buildPassportScannerSection(),
                  const SizedBox(height: 16),

                  // ============================================================
                  // SECTION 0.5: EXTRACTED PASSPORT & ADDRESS DETAILS
                  // ============================================================
                  _buildPassportDetailsSection(),
                  const SizedBox(height: 16),
                  _buildAddressDetailsSection(),
                  const SizedBox(height: 16),

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
                      () {
                        final uniqueExamTypes = <DropdownMenuItem<int>>[];
                        final seenExamIds = <int>{};
                        for (final e in examTypesList) {
                          final id = int.tryParse('${e['id']}');
                          if (id != null && seenExamIds.add(id)) {
                            uniqueExamTypes.add(
                              DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  '${e['name'] ?? ''}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            );
                          }
                        }
                        final effectiveExamId = (selectedExamTypeId != null &&
                                seenExamIds.contains(selectedExamTypeId))
                            ? selectedExamTypeId
                            : null;
                        return DropdownButtonFormField<int>(
                          value: effectiveExamId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(
                              Icons.menu_book_rounded,
                              size: 20,
                            ),
                          ),
                          hint: const Text('Select exam type'),
                          items: uniqueExamTypes,
                          onChanged: (val) {
                            setState(() {
                              selectedExamTypeId = val;
                              selectedTeamId = null;
                            });
                          },
                        );
                      }(),

                      const SizedBox(height: 14),

                      // Team
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildLabel('Team (Optional)'),
                          TextButton.icon(
                            onPressed: _showCreateTeamDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Team'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (loadingTeams)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(
                            color: AppColors.primary,
                            backgroundColor: Color(0xFFEDE9FE),
                          ),
                        )
                      else if (teamsError != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  teamsError!,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadTeams,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        () {
                          final uniqueTeamItems = <DropdownMenuItem<int>>[];
                          final seenTeamIds = <int>{};
                          seenTeamIds.add(-1);
                          uniqueTeamItems.add(
                            DropdownMenuItem<int>(
                              value: -1,
                              child: Text(
                                filteredTeams.isEmpty
                                    ? 'Not Assigned (No teams available)'
                                    : 'Not Assigned',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                          for (final t in filteredTeams) {
                            if (seenTeamIds.add(t.id)) {
                              uniqueTeamItems.add(
                                DropdownMenuItem<int>(
                                  value: t.id,
                                  child: Text(
                                    t.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }
                          }
                          final effectiveTeamId = (selectedTeamId != null &&
                                  seenTeamIds.contains(selectedTeamId))
                              ? selectedTeamId!
                              : -1;
                          return DropdownButtonFormField<int>(
                            value: effectiveTeamId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.groups_rounded,
                                size: 20,
                              ),
                            ),
                            hint: const Text('Select team (optional)'),
                            items: uniqueTeamItems,
                            onChanged: (val) {
                              setState(() {
                                selectedTeamId =
                                    (val == null || val == -1) ? null : val;
                              });
                            },
                          );
                        }(),
                        if (filteredTeams.isEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  size: 16,
                                  color: Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'No teams available for this exam. You can add one now.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _showCreateTeamDialog,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    '+ Create Team',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],

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
                            const SizedBox(width: 8),
                            _buildStatusOption(
                              label: 'Completed',
                              icon: Icons.check_circle_rounded,
                              activeColor: const Color(0xFF16A34A),
                              activeBg: const Color(0xFFDCFCE7),
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

  // ============================================================
  // PASSPORT SCANNER UI (WORKFLOW STEPS 1-7)
  // ============================================================
  Widget _buildPassportScannerSection() {
    return _buildCard(
      title: 'AI PASSPORT SCANNER (GROQ VISION)',
      icon: Icons.document_scanner_rounded,
      accentColor: const Color(0xFF6366F1),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF4F46E5), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  !_frontImageConfirmed
                      ? 'Step 1 of 3: Capture Passport Front (Biodata Page)'
                      : !_lastImageConfirmed
                          ? 'Step 2 of 3: Capture Passport Last (Address Page)'
                          : 'Step 3 of 3: Verify previews and scan with Groq AI',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3730A3),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // STEP 1-3: FRONT PAGE
        if (!_frontImageConfirmed) ...[
          if (_tempFrontPath == null) ...[
            _buildCaptureButton(
              title: 'Capture Passport Front Page',
              subtitle: 'Biodata page with photo, name, and passport number',
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF4F46E5),
              onPressed: _captureFrontPage,
            ),
          ] else ...[
            _buildImagePreviewBox(
              label: 'Front Page Preview',
              filePath: _tempFrontPath!,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retakeFrontPage,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirmFrontPage,
                    icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                    label: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ]
        // STEP 4-6: LAST PAGE
        else if (!_lastImageConfirmed) ...[
          // Show confirmed front page snippet
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Front page confirmed',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                ),
                TextButton(
                  onPressed: _retakeFrontPage,
                  child: const Text('Retake', style: TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (_tempLastPath == null) ...[
            _buildCaptureButton(
              title: 'Capture Passport Last Page',
              subtitle: 'Address page with father/mother name and residential address',
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF0D9488),
              onPressed: _captureLastPage,
            ),
          ] else ...[
            _buildImagePreviewBox(
              label: 'Last Page (Address) Preview',
              filePath: _tempLastPath!,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retakeLastPage,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _confirmLastPage,
                    icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                    label: const Text('Confirm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ]
        // STEP 7: BOTH CONFIRMED -> READY TO EXTRACT
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildImagePreviewBox(
                      label: 'Front Page',
                      filePath: _frontImagePath!,
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: isScanningPassport ? null : _retakeFrontPage,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Retake Front', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _buildImagePreviewBox(
                      label: 'Last Page',
                      filePath: _lastImagePath!,
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: isScanningPassport ? null : _retakeLastPage,
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Retake Last', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Groq AI Scan CTA Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isScanningPassport ? null : _scanPassportWithGroq,
              icon: isScanningPassport
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              label: Text(
                isScanningPassport ? 'Processing with Groq AI...' : 'Scan Passport & Extract Details',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            ),
          ),
        ],

        // Status / feedback message
        if (passportScanStatusMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: passportExtractionSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: passportExtractionSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  passportExtractionSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  color: passportExtractionSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    passportScanStatusMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: passportExtractionSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCaptureButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.3), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreviewBox({
    required String label,
    required String filePath,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: const Color(0xFF374151),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(
              height: 160,
              child: kIsWeb
                  ? Image.network(filePath, fit: BoxFit.cover)
                  : Image.file(File(filePath), fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PASSPORT DETAILS SECTION (STEP 10 & 11)
  // ============================================================
  Widget _buildPassportDetailsSection() {
    return _buildCard(
      title: 'PASSPORT INFORMATION',
      icon: Icons.badge_rounded,
      accentColor: const Color(0xFF2563EB),
      children: [
        _buildLabel('Full Name on Passport'),
        const SizedBox(height: 6),
        TextFormField(
          controller: passportFullNameCtrl,
          decoration: const InputDecoration(
            hintText: 'e.g. JOHN DOE',
            prefixIcon: Icon(Icons.person_pin_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Passport Number'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passportNumberCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Z1234567',
                      prefixIcon: Icon(Icons.numbers_rounded, size: 20),
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
                  _buildLabel('Date of Birth'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passportDobCtrl,
                    decoration: const InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.cake_rounded, size: 20),
                    ),
                  ),
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
                  _buildLabel('Gender'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passportGenderCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Male / Female',
                      prefixIcon: Icon(Icons.transgender_rounded, size: 20),
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
                  _buildLabel('Nationality'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passportNationalityCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Indian',
                      prefixIcon: Icon(Icons.flag_rounded, size: 20),
                    ),
                  ),
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
                  _buildLabel('Date of Issue'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passportIssueDateCtrl,
                    decoration: const InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.calendar_today_rounded, size: 20),
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
                  _buildLabel('Date of Expiry'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: passportExpiryDateCtrl,
                    decoration: const InputDecoration(
                      hintText: 'YYYY-MM-DD',
                      prefixIcon: Icon(Icons.event_busy_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (scanDateCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildLabel('Passport Scan Date & Time (IST)'),
          const SizedBox(height: 6),
          TextFormField(
            controller: scanDateCtrl,
            readOnly: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.access_time_rounded, size: 20),
              filled: true,
              fillColor: Color(0xFFF3F4F6),
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // ADDRESS DETAILS SECTION (FROM LAST PAGE)
  // ============================================================
  Widget _buildAddressDetailsSection() {
    return _buildCard(
      title: 'RESIDENTIAL ADDRESS (FROM LAST PAGE)',
      icon: Icons.home_rounded,
      accentColor: const Color(0xFF059669),
      children: [
        _buildLabel('Address Line 1'),
        const SizedBox(height: 6),
        TextFormField(
          controller: addressLine1Ctrl,
          decoration: const InputDecoration(
            hintText: 'House / Door No., Street, Area',
            prefixIcon: Icon(Icons.place_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 14),

        _buildLabel('Address Line 2'),
        const SizedBox(height: 6),
        TextFormField(
          controller: addressLine2Ctrl,
          decoration: const InputDecoration(
            hintText: 'Locality, Landmark',
            prefixIcon: Icon(Icons.add_location_alt_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('City / District'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(
                      hintText: 'City name',
                      prefixIcon: Icon(Icons.location_city_rounded, size: 20),
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
                  _buildLabel('State'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: stateCtrl,
                    decoration: const InputDecoration(
                      hintText: 'State',
                      prefixIcon: Icon(Icons.map_rounded, size: 20),
                    ),
                  ),
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
                  _buildLabel('PIN / Postal Code'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: postalCodeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 600001',
                      prefixIcon: Icon(Icons.pin_drop_rounded, size: 20),
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
                  _buildLabel('Country'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: countryCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. India',
                      prefixIcon: Icon(Icons.public_rounded, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

