import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../providers/auth_provider.dart';

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentPath = GoRouterState.of(context).uri.path;
    final isAdmin = auth.isOrgAdmin || auth.isSuperAdmin;

    String title = 'Emergency Healthcare';
    if (isAdmin) {
      if (auth.isSuperAdmin) {
        title = 'Platform Admin';
      } else if (auth.organizationName != null) {
        title = auth.organizationName!;
      }
    }

    return AppBar(
      toolbarHeight: 64,
      title: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => context.go(isAdmin ? '/admin/dashboard' : '/'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(title, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!isAdmin) ...[
          _NavButton(
            label: 'Beds',
            icon: Icons.bed_outlined,
            isActive: currentPath.startsWith('/beds'),
            onTap: () => context.go('/beds'),
          ),
          _NavButton(
            label: 'Ambulance',
            icon: Icons.emergency_outlined,
            isActive: currentPath.startsWith('/ambulance'),
            onTap: () => context.go('/ambulance'),
          ),
          _NavButton(
            label: 'Blood',
            icon: Icons.bloodtype_outlined,
            isActive: currentPath.startsWith('/blood'),
            onTap: () => context.go('/blood'),
          ),
          _NavButton(
            label: 'Tests',
            icon: Icons.science_outlined,
            isActive: currentPath.startsWith('/tests'),
            onTap: () => context.go('/tests'),
          ),
          const SizedBox(width: 4),
          if (auth.isAuthenticated)
            _NavButton(
              label: 'My Bookings',
              icon: Icons.list_alt_outlined,
              isActive: currentPath == '/my-bookings',
              onTap: () => context.go('/my-bookings'),
            ),
        ],
        if (auth.isAuthenticated && auth.isOrgAdmin)
          _NavButton(
            label: 'Admin',
            icon: Icons.admin_panel_settings_outlined,
            isActive: currentPath.startsWith('/admin'),
            onTap: () => context.go('/admin/dashboard'),
          ),
        if (auth.isAuthenticated && auth.isSuperAdmin)
          _NavButton(
            label: 'Platform',
            icon: Icons.settings_outlined,
            isActive: currentPath.startsWith('/super-admin'),
            onTap: () => context.go('/super-admin/dashboard'),
          ),
        const SizedBox(width: 8),
        if (auth.isAuthenticated) ...[
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: AppTheme.textSecondary),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            tooltip: 'Sign Out',
            onPressed: () => auth.signOut(),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: FilledButton(
              onPressed: () => context.go('/login'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text('Sign In'),
            ),
          ),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// Nav item with animated hover background and an active-state
/// underline that slides in.
class _NavButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? AppTheme.primary
        : _hovered
            ? AppTheme.textPrimary
            : AppTheme.textSecondary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppTheme.fast,
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hovered && !widget.isActive
                ? AppTheme.background
                : widget.isActive
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, size: 18, color: color),
              const SizedBox(width: 7),
              AnimatedDefaultTextStyle(
                duration: AppTheme.fast,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
