import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class AppNavBar extends StatelessWidget implements PreferredSizeWidget {
  const AppNavBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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
      title: GestureDetector(
        onTap: () => context.go(isAdmin ? '/admin/dashboard' : '/'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_hospital, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      actions: [
        if (!isAdmin) ...[
          _NavButton(
            label: 'Beds',
            icon: Icons.bed,
            isActive: currentPath == '/beds',
            onTap: () => context.go('/beds'),
          ),
          _NavButton(
            label: 'Ambulance',
            icon: Icons.emergency,
            isActive: currentPath == '/ambulance',
            onTap: () => context.go('/ambulance'),
          ),
          _NavButton(
            label: 'Blood',
            icon: Icons.bloodtype,
            isActive: currentPath == '/blood',
            onTap: () => context.go('/blood'),
          ),
          _NavButton(
            label: 'Tests',
            icon: Icons.science,
            isActive: currentPath == '/tests',
            onTap: () => context.go('/tests'),
          ),
          const SizedBox(width: 8),
          if (auth.isAuthenticated)
            _NavButton(
              label: 'My Bookings',
              icon: Icons.list_alt,
              isActive: currentPath == '/my-bookings',
              onTap: () => context.go('/my-bookings'),
            ),
        ],
        if (auth.isAuthenticated && auth.isOrgAdmin)
          _NavButton(
            label: 'Admin',
            icon: Icons.admin_panel_settings,
            isActive: currentPath.startsWith('/admin'),
            onTap: () => context.go('/admin/dashboard'),
          ),
        if (auth.isAuthenticated && auth.isSuperAdmin)
          _NavButton(
            label: 'Platform',
            icon: Icons.settings,
            isActive: currentPath.startsWith('/super-admin'),
            onTap: () => context.go('/super-admin/dashboard'),
          ),
        const SizedBox(width: 8),
        if (auth.isAuthenticated) ...[
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () => context.go('/profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () => auth.signOut(),
          ),
        ] else
          FilledButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Sign In'),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: isActive ? Theme.of(context).colorScheme.primary : null),
      label: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    );
  }
}
