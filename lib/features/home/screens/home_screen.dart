import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 32),
              Text(
                'Emergency Healthcare\nAccess Platform',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Find hospitals, ambulances, blood banks, and diagnostic tests near you.\nCompare prices. Book instantly.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
              const SizedBox(height: 48),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _ServiceCard(
                    icon: Icons.bed,
                    title: 'Emergency Beds',
                    description: 'Find available hospital beds nearby with real-time availability and pricing',
                    color: Colors.blue,
                    onTap: () => context.go('/beds'),
                  ),
                  _ServiceCard(
                    icon: Icons.emergency,
                    title: 'Ambulance',
                    description: 'Book the nearest available ambulance with upfront fare estimates',
                    color: Colors.red,
                    onTap: () => context.go('/ambulance'),
                  ),
                  _ServiceCard(
                    icon: Icons.bloodtype,
                    title: 'Blood Bank',
                    description: 'Find matching blood units across partnered organizations',
                    color: Colors.red.shade800,
                    onTap: () => context.go('/blood'),
                  ),
                  _ServiceCard(
                    icon: Icons.science,
                    title: 'Diagnostic Tests',
                    description: 'Compare prices and availability for medical tests near you',
                    color: Colors.teal,
                    onTap: () => context.go('/tests'),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All prices shown are estimates provided by the organizations. '
                        'The platform assists coordination — it does not replace medical or dispatch judgment.',
                        style: TextStyle(color: Colors.blue.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
