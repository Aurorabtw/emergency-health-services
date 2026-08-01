import 'package:flutter/material.dart';
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
      child: Builder(
        builder: (context) {
          final authProvider = context.watch<AuthProvider>();
          final router = createRouter(authProvider);

          return MaterialApp.router(
            title: 'Emergency Healthcare',
            theme: AppTheme.lightTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
