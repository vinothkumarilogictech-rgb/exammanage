import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/branch_context.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Log out', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branchContext = context.watch<BranchContext>();
    final isAdmin = auth.role.trim().toLowerCase() == 'admin';
    final initial = auth.username.isNotEmpty ? auth.username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FD),
      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        toolbarHeight: AppBarStyle.height,
        shape: AppBarStyle.shape,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: AppBarStyle.gradientDecoration()),
        title: const Text('Profile', style: AppBarStyle.titleStyle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 30),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: brandLinearGradient(),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(.35), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              auth.username.isEmpty ? '-' : auth.username,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: AppColors.tint, borderRadius: BorderRadius.circular(20)),
              child: Text(
                auth.role,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 12.5),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _SectionCard(
            title: 'Account',
            icon: Icons.badge_outlined,
            children: [
              _InfoRow(icon: Icons.person_outline, label: 'Username', value: auth.username.isEmpty ? '-' : auth.username),
              _InfoRow(icon: Icons.verified_user_outlined, label: 'Role', value: auth.role),
              if (!isAdmin)
                _InfoRow(
                  icon: Icons.tag_rounded,
                  label: 'Employee ID',
                  value: auth.employeeId != null ? '${auth.employeeId}' : '-',
                  last: true,
                )
              else
                _InfoRow(
                  icon: Icons.account_tree_outlined,
                  label: 'Active Branch',
                  value: branchContext.selectedBranchName,
                  last: true,
                ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.red,
                side: const BorderSide(color: AppColors.red, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _InfoRow({required this.icon, required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        ],
      ),
    );
  }
}
