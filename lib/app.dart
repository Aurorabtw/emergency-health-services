import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'features/ambulance/providers/ambulance_provider.dart';
import 'features/beds/providers/bed_provider.dart';
import 'features/blood_bank/providers/blood_provider.dart';
import 'features/tests/providers/test_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/booking_provider.dart';
import 'providers/location_provider.dart';
import 'providers/organization_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => OrganizationProvider()),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => BedProvider()),
        ChangeNotifierProvider(create: (_) => BloodProvider()),
        ChangeNotifierProvider(create: (_) => AmbulanceProvider()),
        ChangeNotifierProvider(create: (_) => TestProvider()),
      ],
      child: const _AppRouter(),
    );
  }
}

/// Holds a single GoRouter instance so it's not recreated on every
/// AuthProvider change. GoRouter's [refreshListenable] handles
/// re-evaluating redirects when auth state changes.
class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    // read (not watch!) — we only need the reference once.
    // GoRouter's refreshListenable re-evaluates redirects internally.
    _router ??= createRouter(context.read<AuthProvider>());

    return MaterialApp.router(
      title: 'Emergency Healthcare',
      theme: AppTheme.lightTheme,
      routerConfig: _router!,
      debugShowCheckedModeBanner: false,
    );
  }

  @override
  void dispose() {
    _router?.dispose();
    super.dispose();
  }
}
