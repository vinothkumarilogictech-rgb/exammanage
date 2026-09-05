import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/branch_context.dart';
import '../models.dart';
import '../services/dio_client.dart';
import '../widgets/common.dart';

class BranchesScreen extends StatefulWidget {
  final bool openAddOnStart;

  const BranchesScreen({
    super.key,
    this.openAddOnStart = false,
  });

  @override
  State<BranchesScreen> createState() => BranchesScreenState();
}

class BranchesScreenState extends State<BranchesScreen> {
  final api = DioClient();
  final search = TextEditingController();

  late Future<List<Branch>> future;
  bool opened = false;

  static const Color _purple = Color(0xFF9A22C7);
  static const Color _purpleDark = Color(0xFF9A3412);
  static const Color _purpleSoft = Color(0xFFEDE9FE);
  static const Color _pageBg = Color(0xFFF7F5FD);

  @override
  void initState() {
    super.initState();
    future = load();

    search.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.openAddOnStart && !opened) {
      opened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => addBranch());
    }
  }

  Future<List<Branch>> load() async {
    final r = await api.branches(q: search.text);

    return (r.data['data'] as List? ?? const [])
        .map((x) => Branch.fromMap(Map<String, dynamic>.from(x)))
        .toList();
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  // ================================================================
  // GLASS DECORATION
  // ================================================================

  BoxDecoration _glassDecoration({
    double radius = 20,
    bool strong = false,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(strong ? .94 : .82),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: Colors.white.withOpacity(.90),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: _purple.withOpacity(.07),
          blurRadius: 24,
          spreadRadius: 1,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  Widget _glass({
    required Widget child,
    EdgeInsetsGeometry padding = EdgeInsets.zero,
    double radius = 20,
    bool strong = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          padding: padding,
          decoration: _glassDecoration(
            radius: radius,
            strong: strong,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _softGlowIcon(
    IconData icon, {
    Color color = _purple,
    double size = 44,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(.16),
            color.withOpacity(.07),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(.10),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.12),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: size * .48,
      ),
    );
  }

  // ================================================================
  // ADD BRANCH
  // ================================================================

  Future<void> addBranch() async {
    final name = TextEditingController();
    final address = TextEditingController();
    final contact = TextEditingController();
    final region = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.38),
      builder: (ctx) => _modalBackground(
        ctx,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _modalHandle(),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  _softGlowIcon(
                    Icons.business_rounded,
                    size: 46,
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF17132A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              _fieldLabel('Branch Name *'),
              const SizedBox(height: 7),
              _textField(
                controller: name,
                hint: 'Enter branch name',
                icon: Icons.apartment_rounded,
              ),

              const SizedBox(height: 15),

              _fieldLabel('Region'),
              const SizedBox(height: 7),
              _textField(
                controller: region,
                hint: 'e.g. North, South, East, West',
                icon: Icons.map_rounded,
              ),

              const SizedBox(height: 15),

              _fieldLabel('Address'),
              const SizedBox(height: 7),
              _textField(
                controller: address,
                hint: 'Full branch address',
                icon: Icons.location_on_rounded,
              ),

              const SizedBox(height: 15),

              _fieldLabel('Contact Info'),
              const SizedBox(height: 7),
              _textField(
                controller: contact,
                hint: 'Phone number or email',
                icon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 25),

              _gradientButton(
                label: 'Save',
                icon: Icons.add_business_rounded,
                onPressed: () async {
                  if (name.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                        content: Text('Branch name is required'),
                      ),
                    );
                    return;
                  }

                  try {
                    await api.createBranch({
                      'branch_name': name.text.trim(),
                      'address': address.text.trim(),
                      'contact_info': contact.text.trim(),
                      'region': region.text.trim(),
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Branch created successfully!',
                            ),
                            backgroundColor: AppColors.green,
                          ),
                        );

                        await context.read<BranchContext>().refreshBranches();
                        reload();
                      }
                    }
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    name.dispose();
    address.dispose();
    contact.dispose();
    region.dispose();
  }

  // ================================================================
  // EDIT BRANCH
  // ================================================================

  Future<void> editBranch(Branch b) async {
    final name = TextEditingController(text: b.name);
    final address = TextEditingController(text: b.address);
    final contact = TextEditingController(text: b.contact);
    final region = TextEditingController(text: b.region);

    String status =
        b.status.toLowerCase() == 'inactive' ? 'Inactive' : 'Active';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.38),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => _modalBackground(
          ctx,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _modalHandle(),
                const SizedBox(height: 18),

                // Header
                Row(
                  children: [
                    _softGlowIcon(
                      Icons.edit_rounded,
                      size: 46,
                    ),
                    const SizedBox(width: 13),
                    const Expanded(
                      child: Text(
                        'Edit Branch',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF17132A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF6B7280),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                _fieldLabel('Branch Name *'),
                const SizedBox(height: 7),
                _textField(
                  controller: name,
                  hint: 'Enter branch name',
                  icon: Icons.apartment_rounded,
                ),

                const SizedBox(height: 15),

                _fieldLabel('Region'),
                const SizedBox(height: 7),
                _textField(
                  controller: region,
                  hint: 'e.g. North, South, East, West',
                  icon: Icons.map_rounded,
                ),

                const SizedBox(height: 15),

                _fieldLabel('Address'),
                const SizedBox(height: 7),
                _textField(
                  controller: address,
                  hint: 'Full branch address',
                  icon: Icons.location_on_rounded,
                ),

                const SizedBox(height: 15),

                _fieldLabel('Phone Number'),
                const SizedBox(height: 7),
                _textField(
                  controller: contact,
                  hint: 'Phone number or contact info',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 17),

                _fieldLabel('Status'),
                const SizedBox(height: 9),

                Row(
                  children: [
                    Expanded(
                      child: _statusButton(
                        label: 'Active',
                        icon: Icons.check_circle_rounded,
                        selected: status == 'Active',
                        color: AppColors.green,
                        onTap: () {
                          setModalState(() {
                            status = 'Active';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statusButton(
                        label: 'Inactive',
                        icon: Icons.cancel_rounded,
                        selected: status == 'Inactive',
                        color: const Color(0xFFE11D48),
                        onTap: () {
                          setModalState(() {
                            status = 'Inactive';
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 53,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(.70),
                            side: BorderSide(
                              color: Colors.grey.shade300,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _gradientButton(
                        label: 'Save Changes',
                        icon: Icons.check_rounded,
                        onPressed: () async {
                          if (name.text.trim().isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Branch name is required',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await api.updateBranch(
                              b.id,
                              {
                                'branch_name': name.text.trim(),
                                'address': address.text.trim(),
                                'contact_info': contact.text.trim(),
                                'region': region.text.trim(),
                                'status': status,
                              },
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Branch updated successfully!',
                                    ),
                                    backgroundColor: AppColors.green,
                                  ),
                                );

                                reload();
                              }
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    name.dispose();
    address.dispose();
    contact.dispose();
    region.dispose();
  }

  // ================================================================
  // ACTIVATE / DEACTIVATE
  // ================================================================

  Future<void> toggleBranchStatus(Branch b) async {
    final newStatus =
        b.status.toLowerCase() == 'active' ? 'Inactive' : 'Active';

    try {
      await api.updateBranch(
        b.id,
        {
          'status': newStatus,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Branch $newStatus successfully!',
            ),
            backgroundColor: newStatus == 'Active'
                ? AppColors.green
                : const Color(0xFFEA580C),
          ),
        );

        await context.read<BranchContext>().refreshBranches();
        reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update status: $e',
            ),
          ),
        );
      }
    }
  }

  // ================================================================
  // DELETE BRANCH
  // ================================================================

  Future<void> confirmDeleteBranch(Branch b) async {
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(.45),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 24,
        ),
        child: _glass(
          radius: 25,
          strong: true,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withOpacity(.12),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE11D48),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Text(
                      'Delete Branch',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        color: Color(0xFF17132A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              const Text(
                'Are you sure you want to delete this branch?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: _purpleSoft,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _purple.withOpacity(.08),
                  ),
                ),
                child: Text(
                  b.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: _purple,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'This action will permanently remove the branch from the list.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF6B7280),
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          double.infinity,
                          48,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48),
                        minimumSize: const Size(
                          double.infinity,
                          48,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 5,
                        shadowColor: const Color(0xFFE11D48).withOpacity(.25),
                      ),
                      onPressed: () async {
                        try {
                          await api.deleteBranch(b.id);

                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Branch deleted successfully!',
                                  ),
                                  backgroundColor: Color(0xFFE11D48),
                                ),
                              );

                              await context.read<BranchContext>().refreshBranches();
        reload();
                            }
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to delete branch: $e',
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // BRANCH DETAILS
  // ================================================================

  void _showBranchDetails(Branch b) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(.38),
      builder: (ctx) => _modalBackground(
        ctx,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modalHandle(),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEDE9FE),
                        Color(0xFFF5F3FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withOpacity(.10),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      b.name.isNotEmpty
                          ? b.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: _purple,
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
                          color: Color(0xFF17132A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _statusBadge(
                        b.status,
                        isActive:
                            b.status.toLowerCase() == 'active',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: _purple,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    editBranch(b);
                  },
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'BRANCH INFORMATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF8B8797),
                letterSpacing: 1.1,
              ),
            ),

            const SizedBox(height: 13),

            _detailGlassRow(
              Icons.map_rounded,
              'Region',
              b.region.isNotEmpty
                  ? b.region
                  : 'Not specified',
            ),

            const SizedBox(height: 10),

            _detailGlassRow(
              Icons.location_on_rounded,
              'Address',
              b.address.isNotEmpty
                  ? b.address
                  : 'Not specified',
            ),

            const SizedBox(height: 10),

            _detailGlassRow(
              Icons.phone_rounded,
              'Contact Info',
              b.contact.isNotEmpty
                  ? b.contact
                  : 'Not specified',
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded),
                label: const Text(
                  'Close',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(.65),
                  side: BorderSide(
                    color: _purple.withOpacity(.18),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailGlassRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7FF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _purple.withOpacity(.06),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: _purple.withOpacity(.08),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 18,
              color: _purple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF8B8797),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF252033),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
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
            boxShadow: [BoxShadow(color: Color(0x559A22C7), blurRadius: 24, offset: Offset(0, 8))],
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
        ),
        title: const Text(
          'Branch',
          style: AppBarStyle.titleStyle,
        ),
        actions: [
          IconButton(
            onPressed: reload,
            tooltip: 'Refresh',
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          // ==========================================================
          // BACKGROUND GLOW
          // ==========================================================

          Positioned(
            top: -80,
            right: -70,
            child: IgnorePointer(
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _purple.withOpacity(.055),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(.08),
                      blurRadius: 80,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B5CF6).withOpacity(.035),
                  boxShadow: [
                    BoxShadow(
                      color: _purple.withOpacity(.06),
                      blurRadius: 70,
                      spreadRadius: 15,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ==========================================================
          // MAIN CONTENT
          // ==========================================================

          Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  13,
                  16,
                  10,
                ),
                child: _glass(
                  radius: 17,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),
                  child: TextField(
                    controller: search,
                    onSubmitted: (_) => reload(),
                    decoration: InputDecoration(
                      hintText:
                          'Search branch by name or location...',
                      hintStyle: const TextStyle(
                        color: Color(0xFF777382),
                        fontSize: 14.5,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(7),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(.09),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.search_rounded,
                          color: _purple,
                          size: 21,
                        ),
                      ),
                      suffixIcon: search.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                search.clear();
                                reload();
                              },
                              icon: const Icon(
                                Icons.clear_rounded,
                                size: 19,
                              ),
                            )
                          : null,
                      filled: false,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // List
              Expanded(
                child: FutureBuilder<List<Branch>>(
                  future: future,
                  builder: (c, s) {
                    if (s.connectionState !=
                        ConnectionState.done) {
                      return const LoadingView();
                    }

                    if (s.hasError) {
                      return ErrorView(
                        message: '${s.error}',
                        onRetry: reload,
                      );
                    }

                    final rows = s.requireData;

                    if (rows.isEmpty) {
                      return _emptyState();
                    }

                    return RefreshIndicator(
                      color: _purple,
                      onRefresh: () async {
                        await context.read<BranchContext>().refreshBranches();
        reload();
                        await future;
                      },
                      child: ListView.builder(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          12,
                          5,
                          12,
                          20,
                        ),
                        itemCount: rows.length,
                        itemBuilder: (c, i) {
                          final b = rows[i];
                          return _branchCard(b);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),

      // Floating Add button
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(.30),
              blurRadius: 20,
              spreadRadius: 1,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: addBranch,
          elevation: 4,
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 28,
          ),
        ),
      ),
    );
  }

  // ================================================================
  // BRANCH CARD
  // ================================================================

  Widget _branchCard(Branch b) {
    final isActive =
        b.status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(.055),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 8,
            sigmaY: 8,
          ),
          child: Material(
            color: Colors.white.withOpacity(.88),
            child: InkWell(
              onTap: () => _showBranchDetails(b),
              borderRadius: BorderRadius.circular(20),
              splashColor: _purple.withOpacity(.05),
              highlightColor: _purple.withOpacity(.025),
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  14,
                  14,
                  7,
                  14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(.95),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFEDE9FE),
                            Color(0xFFF5F3FF),
                          ],
                        ),
                        borderRadius:
                            BorderRadius.circular(15),
                        border: Border.all(
                          color: _purple.withOpacity(.07),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                _purple.withOpacity(.08),
                            blurRadius: 13,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          b.name.isNotEmpty
                              ? b.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: _purple,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.5,
                              color: Color(0xFF252033),
                            ),
                          ),

                          if (b.region.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                const Icon(
                                  Icons.map_rounded,
                                  size: 13,
                                  color: Color(0xFF8C8796),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    b.region,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          Color(0xFF666171),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (b.address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 13,
                                  color: Color(0xFFA29DA8),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    b.address,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize: 11.5,
                                      color:
                                          Color(0xFF77727E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          if (b.contact.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 13,
                                  color: Color(0xFFA29DA8),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    b.contact,
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      fontSize: 11.5,
                                      color:
                                          Color(0xFF77727E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 5),

                    // Right actions
                    Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        _statusBadge(
                          b.status,
                          isActive: isActive,
                        ),

                        const SizedBox(height: 1),

                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Color(0xFF6F6978),
                            size: 21,
                          ),
                          padding: EdgeInsets.zero,
                          tooltip: 'Branch actions',
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          onSelected: (value) {
                            if (value == 'edit') {
                              editBranch(b);
                            } else if (value ==
                                'toggle') {
                              toggleBranchStatus(b);
                            } else if (value ==
                                'delete') {
                              confirmDeleteBranch(b);
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: _purple,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Edit Branch',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons
                                            .block_rounded
                                        : Icons
                                            .check_circle_outline_rounded,
                                    size: 18,
                                    color: isActive
                                        ? const Color(
                                            0xFFEA580C,
                                          )
                                        : AppColors.green,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    isActive
                                        ? 'Deactivate Branch'
                                        : 'Activate Branch',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight:
                                          FontWeight.w600,
                                      color: isActive
                                          ? const Color(
                                              0xFFEA580C,
                                            )
                                          : AppColors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const PopupMenuDivider(
                              height: 1,
                            ),

                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons
                                        .delete_outline_rounded,
                                    size: 18,
                                    color:
                                        Color(0xFFE11D48),
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Delete Branch',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight:
                                          FontWeight.w600,
                                      color:
                                          Color(0xFFE11D48),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // STATUS BADGE
  // ================================================================

  Widget _statusBadge(
    String status, {
    required bool isActive,
  }) {
    final color = isActive
        ? AppColors.green
        : const Color(0xFF6B7280);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFDCFCE7).withOpacity(.90)
            : const Color(0xFFF1F2F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.green.withOpacity(.10)
              : Colors.grey.withOpacity(.08),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ================================================================
  // EMPTY STATE
  // ================================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: _glass(
          radius: 25,
          padding: const EdgeInsets.all(28),
          strong: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _softGlowIcon(
                Icons.business_rounded,
                size: 62,
              ),
              const SizedBox(height: 18),
              const Text(
                'No branches found',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF252033),
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Add your first branch to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF77727E),
                ),
              ),
              const SizedBox(height: 19),
              FilledButton.icon(
                onPressed: addBranch,
                icon: const Icon(
                  Icons.add_rounded,
                ),
                label: const Text(
                  'Add Branch',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  elevation: 5,
                  shadowColor:
                      _purple.withOpacity(.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // MODAL HELPERS
  // ================================================================

  Widget _modalBackground(
    BuildContext ctx, {
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCFF).withOpacity(.97),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(.15),
            blurRadius: 35,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        MediaQuery.of(ctx).viewInsets.bottom + 22,
      ),
      child: child,
    );
  }

  Widget _modalHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFFD8D0EA),
              Color(0xFFB9A9D9),
            ],
          ),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 12.5,
        color: Color(0xFF514B5D),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: _purple.withOpacity(.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF272232),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFA19CA8),
            fontSize: 13.5,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(7),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _purple.withOpacity(.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: 19,
              color: _purple,
            ),
          ),
          filled: true,
          fillColor: const Color(0xFFF9F8FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.withOpacity(.12),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.grey.withOpacity(.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(
              color: _purple,
              width: 1.5,
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _gradientButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 53,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF9A22C7),
              Color(0xFF6C1FB0),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _purple.withOpacity(.24),
              blurRadius: 18,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(
            icon,
            size: 20,
          ),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusButton({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(.09)
              : const Color(0xFFF8F7FA),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? color.withOpacity(.65)
                : Colors.grey.withOpacity(.14),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(.09),
                    blurRadius: 13,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? color
                  : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected
                    ? color
                    : const Color(0xFF6B7280),
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}