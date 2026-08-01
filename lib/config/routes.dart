import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/booking_request_model.dart';
import '../providers/booking_provider.dart';
import '../shared/widgets/booking_status_chip.dart';
import '../shared/widgets/price_widget.dart';
import '../features/admin/org_admin/screens/org_admin_dashboard.dart';
import '../features/admin/super_admin/screens/manage_organizations_screen.dart';
import '../features/admin/super_admin/screens/manage_users_screen.dart';
import '../features/admin/super_admin/screens/super_admin_dashboard.dart';
import '../features/ambulance/screens/admin/ambulance_requests_screen.dart';
import '../features/ambulance/screens/admin/manage_fleet_screen.dart';
import '../features/ambulance/screens/ambulance_booking_screen.dart';
import '../features/ambulance/screens/ambulance_listings_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/beds/screens/admin/bed_requests_screen.dart';
import '../features/beds/screens/admin/manage_beds_screen.dart';
import '../features/beds/screens/bed_booking_screen.dart';
import '../features/beds/screens/bed_listings_screen.dart';
import '../features/blood_bank/screens/admin/blood_requests_screen.dart';
import '../features/blood_bank/screens/admin/manage_blood_stock_screen.dart';
import '../features/blood_bank/screens/blood_listings_screen.dart';
import '../features/blood_bank/screens/blood_request_screen.dart';
import '../features/bookings/screens/booking_detail_screen.dart';
import '../features/bookings/screens/my_bookings_screen.dart';
import '../features/home/screens/home_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/tests/screens/admin/manage_tests_screen.dart';
import '../features/tests/screens/test_search_screen.dart';
import '../navigation/app_shell.dart';
import '../providers/auth_provider.dart';

final navigatorKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: navigatorKey,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isLoggedIn = authProvider.isAuthenticated;
      final isLoading = authProvider.isLoading;
      final path = state.uri.path;

      if (isLoading) return null;

      if (path == '/login' && isLoggedIn) {
        if (authProvider.isSuperAdmin) return '/super-admin/dashboard';
        if (authProvider.isOrgAdmin) return '/admin/dashboard';
        return '/';
      }

      if (path == '/' && isLoggedIn) {
        if (authProvider.isSuperAdmin) return '/super-admin/dashboard';
        if (authProvider.isOrgAdmin) return '/admin/dashboard';
      }

      if (path.startsWith('/super-admin')) {
        if (!isLoggedIn) return '/login';
        if (!authProvider.isSuperAdmin) return '/';
      }

      if (path.startsWith('/admin')) {
        if (!isLoggedIn) return '/login';
        if (!authProvider.isOrgAdmin) return '/';
      }

      if (path == '/my-bookings' || path.startsWith('/booking/')) {
        if (!isLoggedIn) return '/login';
      }

      if (path == '/profile') {
        if (!isLoggedIn) return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (_, __, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/beds', builder: (_, __) => const BedListingsScreen()),
          GoRoute(
            path: '/beds/book/:orgId',
            builder: (_, state) => BedBookingScreen(organizationId: state.pathParameters['orgId']!),
          ),
          GoRoute(path: '/ambulance', builder: (_, __) => const AmbulanceListingsScreen()),
          GoRoute(
            path: '/ambulance/book/:orgId',
            builder: (_, state) => AmbulanceBookingScreen(organizationId: state.pathParameters['orgId']!),
          ),
          GoRoute(path: '/blood', builder: (_, __) => const BloodListingsScreen()),
          GoRoute(
            path: '/blood/request/:orgId',
            builder: (_, state) => BloodRequestScreen(organizationId: state.pathParameters['orgId']!),
          ),
          GoRoute(path: '/tests', builder: (_, __) => const TestSearchScreen()),
          GoRoute(path: '/my-bookings', builder: (_, __) => const MyBookingsScreen()),
          GoRoute(
            path: '/booking/:id',
            builder: (_, state) => BookingDetailScreen(bookingId: state.pathParameters['id']!),
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

          // Admin routes
          GoRoute(path: '/admin/dashboard', builder: (_, __) => const OrgAdminDashboard()),
          GoRoute(path: '/admin/beds', builder: (_, __) => const ManageBedsScreen()),
          GoRoute(path: '/admin/ambulances', builder: (_, __) => const ManageFleetScreen()),
          GoRoute(path: '/admin/blood-stock', builder: (_, __) => const ManageBloodStockScreen()),
          GoRoute(path: '/admin/tests', builder: (_, __) => const ManageTestsScreen()),
          GoRoute(path: '/admin/requests', builder: (_, __) => const _AdminRequestsRouter()),

          // Super Admin routes
          GoRoute(path: '/super-admin/dashboard', builder: (_, __) => const SuperAdminDashboard()),
          GoRoute(path: '/super-admin/organizations', builder: (_, __) => const ManageOrganizationsScreen()),
          GoRoute(path: '/super-admin/users', builder: (_, __) => const ManageUsersScreen()),
          GoRoute(path: '/super-admin/requests', builder: (_, __) => const _SuperAdminRequestsView()),
        ],
      ),
    ],
  );
}

class _AdminRequestsRouter extends StatelessWidget {
  const _AdminRequestsRouter();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isHospitalAdmin) return const BedRequestsScreen();
    if (auth.isBloodBankAdmin) return const BloodRequestsScreen();
    if (auth.isAmbulanceAdmin) return const AmbulanceRequestsScreen();

    return const Scaffold(body: Center(child: Text('No requests to manage')));
  }
}

class _SuperAdminRequestsView extends StatefulWidget {
  const _SuperAdminRequestsView();

  @override
  State<_SuperAdminRequestsView> createState() => _SuperAdminRequestsViewState();
}

class _SuperAdminRequestsViewState extends State<_SuperAdminRequestsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRequests();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final types = [null, 'bed', 'blood', 'ambulance'];
    _typeFilter = types[_tabController.index];
    _loadRequests();
  }

  void _loadRequests() {
    context.read<BookingProvider>().fetchAllBookings(type: _typeFilter);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingProvider = context.watch<BookingProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('All Booking Requests', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(icon: Icon(Icons.bed, size: 18), text: 'Beds'),
                  Tab(icon: Icon(Icons.bloodtype, size: 18), text: 'Blood'),
                  Tab(icon: Icon(Icons.emergency, size: 18), text: 'Ambulance'),
                ],
              ),
              const SizedBox(height: 16),
              if (bookingProvider.isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()))
              else if (bookingProvider.bookings.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(48), child: Text('No booking requests')))
              else
                ...bookingProvider.bookings.map((booking) => _RequestCard(booking: booking, onRefresh: _loadRequests)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final BookingRequestModel booking;
  final VoidCallback onRefresh;

  const _RequestCard({required this.booking, required this.onRefresh});

  IconData _typeIcon(String type) {
    switch (type) {
      case 'bed': return Icons.bed;
      case 'ambulance': return Icons.emergency;
      case 'blood': return Icons.bloodtype;
      default: return Icons.info;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'bed': return Colors.blue;
      case 'ambulance': return Colors.orange;
      case 'blood': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bed': return 'Bed';
      case 'ambulance': return 'Ambulance';
      case 'blood': return 'Blood';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor(booking.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(booking.type), size: 14, color: _typeColor(booking.type)),
                      const SizedBox(width: 4),
                      Text(_typeLabel(booking.type), style: TextStyle(color: _typeColor(booking.type), fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (booking.organizationName != null)
                  Expanded(child: Text(booking.organizationName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)))
                else
                  const Spacer(),
                BookingStatusChip(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(booking.patientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Phone: ${booking.contactNumber}'),
            if (booking.type == 'bed') Text('Bed Type: ${booking.bedType ?? "-"}'),
            if (booking.type == 'blood') Text('Blood: ${booking.bloodType ?? "-"}  |  Units: ${booking.unitsNeeded ?? 0}'),
            if (booking.type == 'ambulance') Text('Ambulance: ${booking.ambulanceType ?? "-"}'),
            if (booking.estimatedPrice != null) PriceWidget(price: booking.estimatedPrice),
            if (booking.isPending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      await context.read<BookingProvider>().rejectBooking(booking.id);
                      onRefresh();
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
