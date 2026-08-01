import 'package:flutter/material.dart';

import 'app_nav_bar.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppNavBar(),
      body: child,
    );
  }
}
