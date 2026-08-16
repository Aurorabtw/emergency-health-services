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
import '../features/admin/super_admin/screens/all_diagnostic_tests_screen.dart';
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
import '../features/tests/screens/admin/diagnostic_queue_overview_screen.dart';
import '../features/tests/screens/admin/test_queue_screen.dart';
import '../features/tests/screens/test_detail_screen.dart';
import '../features/tests/screens/test_search_screen.dart';
import '../navigation/app_shell.dart';
import '../providers/auth_provider.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Fast opacity transition used for all in-shell navigation.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: const Duration(milliseconds: 120),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        child: child,
      );
    },
  );
}

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
        final redirectPath = state.uri.queryParameters['redirect'];
        if (redirectPath != null &&
            redirectPath.startsWith('/') &&
            !redirectPath.startsWith('/login')) {
          return redirectPath;
        }
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
        if (path == '/admin/beds' && !authProvider.isBedAdmin) {
          return '/admin/dashboard';
        }
        if (path.startsWith('/admin/tests') && !authProvider.isTestAdmin) {
          return '/admin/dashboard';
        }
        if (path == '/admin/test-queue' && !authProvider.isTestAdmin) {
          return '/admin/dashboard';
        }
        if (path == '/admin/blood-stock' && !authProvider.isBloodBankAdmin) {
          return '/admin/dashboard';
        }
        if (path == '/admin/ambulances' && !authProvider.isAmbulanceAdmin) {
          return '/admin/dashboard';
        }
        if (path == '/admin/requests' &&
            authProvider.isTestAdmin &&
            !authProvider.isBedAdmin) {
          return '/admin/dashboard';
        }
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
      GoRoute(
        path: '/login',
        pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
      ),
      ShellRoute(
        builder: (_, _, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
          ),
          GoRoute(
            path: '/beds',
            pageBuilder: (_, state) =>
                _fadePage(state, const BedListingsScreen()),
          ),
          GoRoute(
            path: '/beds/book/:orgId',
            pageBuilder: (_, state) => _fadePage(
              state,
              BedBookingScreen(organizationId: state.pathParameters['orgId']!),
            ),
          ),
          GoRoute(
            path: '/ambulance',
            pageBuilder: (_, state) =>
                _fadePage(state, const AmbulanceListingsScreen()),
          ),
          GoRoute(
            path: '/ambulance/book/:orgId',
            pageBuilder: (_, state) => _fadePage(
              state,
              AmbulanceBookingScreen(
                organizationId: state.pathParameters['orgId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/blood',
            pageBuilder: (_, state) =>
                _fadePage(state, const BloodListingsScreen()),
          ),
          GoRoute(
            path: '/blood/request/:orgId',
            pageBuilder: (_, state) => _fadePage(
              state,
              BloodRequestScreen(
                organizationId: state.pathParameters['orgId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/tests',
            pageBuilder: (_, state) =>
                _fadePage(state, const TestSearchScreen()),
          ),
          GoRoute(
            path: '/tests/:orgId/:testId',
            pageBuilder: (_, state) => _fadePage(
              state,
              TestDetailScreen(
                organizationId: state.pathParameters['orgId']!,
                testId: state.pathParameters['testId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/my-bookings',
            pageBuilder: (_, state) =>
                _fadePage(state, const MyBookingsScreen()),
          ),
          GoRoute(
            path: '/booking/:id',
            pageBuilder: (_, state) => _fadePage(
              state,
              BookingDetailScreen(bookingId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, state) => _fadePage(state, const ProfileScreen()),
          ),

          // Admin routes
          GoRoute(
            path: '/admin/dashboard',
            pageBuilder: (_, state) =>
                _fadePage(state, const OrgAdminDashboard()),
          ),
          GoRoute(
            path: '/admin/beds',
            pageBuilder: (_, state) =>
                _fadePage(state, const ManageBedsScreen()),
          ),
          GoRoute(
            path: '/admin/ambulances',
            pageBuilder: (_, state) =>
                _fadePage(state, const ManageFleetScreen()),
          ),
          GoRoute(
            path: '/admin/blood-stock',
            pageBuilder: (_, state) =>
                _fadePage(state, const ManageBloodStockScreen()),
          ),
          GoRoute(
            path: '/admin/tests',
            pageBuilder: (_, state) =>
                _fadePage(state, const ManageTestsScreen()),
          ),
          GoRoute(
            path: '/admin/test-queue',
            pageBuilder: (_, state) => _fadePage(
              state,
              DiagnosticQueueOverviewScreen(
                initialStatus: state.uri.queryParameters['status'] ?? 'waiting',
              ),
            ),
          ),
          GoRoute(
            path: '/admin/tests/:testId/queue',
            pageBuilder: (_, state) => _fadePage(
              state,
              TestQueueScreen(testId: state.pathParameters['testId']!),
            ),
          ),
          GoRoute(
            path: '/admin/requests',
            pageBuilder: (_, state) =>
                _fadePage(state, const _AdminRequestsRouter()),
          ),

          // Super Admin routes
          GoRoute(
            path: '/super-admin/dashboard',
            pageBuilder: (_, state) =>
                _fadePage(state, const SuperAdminDashboard()),
          ),
          GoRoute(
            path: '/super-admin/organizations',
            pageBuilder: (_, state) {
              final requestedType = state.uri.queryParameters['type'];
              final typeFilter =
                  const {
                    'hospital',
                    'blood_bank',
                    'ambulance_operator',
                  }.contains(requestedType)
                  ? requestedType
                  : null;
              return _fadePage(
                state,
                ManageOrganizationsScreen(typeFilter: typeFilter),
              );
            },
          ),
          GoRoute(
            path: '/super-admin/users',
            pageBuilder: (_, state) =>
                _fadePage(state, const ManageUsersScreen()),
          ),
          GoRoute(
            path: '/super-admin/requests',
            pageBuilder: (_, state) =>
                _fadePage(state, const _SuperAdminRequestsView()),
          ),
          GoRoute(
            path: '/super-admin/diagnostic-tests',
            pageBuilder: (_, state) =>
                _fadePage(state, const AllDiagnosticTestsScreen()),
          ),
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

    if (auth.isBedAdmin) return const BedRequestsScreen();
    if (auth.isBloodBankAdmin) return const BloodRequestsScreen();
    if (auth.isAmbulanceAdmin) return const AmbulanceRequestsScreen();

    return const Scaffold(body: Center(child: Text('No requests to manage')));
  }
}

class _SuperAdminRequestsView extends StatefulWidget {
  const _SuperAdminRequestsView();

  @override
  State<_SuperAdminRequestsView> createState() =>
      _SuperAdminRequestsViewState();
}

class _SuperAdminRequestsViewState extends State<_SuperAdminRequestsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRequests();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final types = [null, 'bed', 'blood', 'ambulance', 'test'];
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
                  Text(
                    'All Booking Requests',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadRequests,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(icon: Icon(Icons.bed, size: 18), text: 'Beds'),
                  Tab(icon: Icon(Icons.bloodtype, size: 18), text: 'Blood'),
                  Tab(icon: Icon(Icons.emergency, size: 18), text: 'Ambulance'),
                  Tab(icon: Icon(Icons.science, size: 18), text: 'Tests'),
                ],
              ),
              const SizedBox(height: 16),
              if (bookingProvider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (bookingProvider.bookings.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: Text('No booking requests'),
                  ),
                )
              else
                ...bookingProvider.bookings.map(
                  (booking) =>
                      _RequestCard(booking: booking, onRefresh: _loadRequests),
                ),
              if (bookingProvider.hasMoreBookings) ...[
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: bookingProvider.isLoading ||
                            bookingProvider.isLoadingMore
                        ? null
                        : () => context.read<BookingProvider>().loadMoreBookings(),
                    icon: bookingProvider.isLoadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      bookingProvider.isLoadingMore
                          ? 'Loading…'
                          : 'Load older requests',
                    ),
                  ),
                ),
              ],
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
      case 'bed':
        return Icons.bed;
      case 'ambulance':
        return Icons.emergency;
      case 'blood':
        return Icons.bloodtype;
      case 'test':
        return Icons.science;
      default:
        return Icons.info;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'bed':
        return Colors.blue;
      case 'ambulance':
        return Colors.orange;
      case 'blood':
        return Colors.red;
      case 'test':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'bed':
        return 'Bed';
      case 'ambulance':
        return 'Ambulance';
      case 'blood':
        return 'Blood';
      case 'test':
        return 'Diagnostic Test';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/booking/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _typeColor(booking.type).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _typeIcon(booking.type),
                          size: 14,
                          color: _typeColor(booking.type),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _typeLabel(booking.type),
                          style: TextStyle(
                            color: _typeColor(booking.type),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (booking.organizationName != null)
                    Expanded(
                      child: Text(
                        booking.organizationName!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  BookingStatusChip(
                    status: booking.status,
                    bookingType: booking.type,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                booking.patientName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text('Phone: ${booking.contactNumber}'),
              if (booking.type == 'bed')
                Text('Bed Type: ${booking.bedType ?? "-"}'),
              if (booking.type == 'blood')
                Text(
                  'Blood: ${booking.bloodType ?? "-"}  |  Units: ${booking.unitsNeeded ?? 0}',
                ),
              if (booking.type == 'ambulance')
                Text('Ambulance: ${booking.ambulanceType ?? "-"}'),
              if (booking.type == 'test')
                Text(
                  '${booking.testName ?? "Diagnostic Test"}  |  Serial #${booking.serialNumber ?? "-"}',
                ),
              if (booking.estimatedPrice != null)
                PriceWidget(price: booking.estimatedPrice),
              if (booking.isPending && booking.type != 'test') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        await context.read<BookingProvider>().rejectBooking(
                          booking.id,
                        );
                        onRefresh();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Reject'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
