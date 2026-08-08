import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/features/auth/presentation/auth_provider.dart';
import 'package:shadja/features/auth/presentation/login_page.dart';
import 'package:shadja/features/auth/presentation/register_page.dart';
import 'package:shadja/features/auth/presentation/splash_page.dart';
import 'package:shadja/features/menu/presentation/kasir_page.dart';
import 'package:shadja/features/order/presentation/order_history_page.dart';
import 'package:shadja/features/printer_settings/presentation/printer_settings_page.dart';
import 'package:shadja/features/profile/presentation/profile_page.dart';
import 'package:shadja/features/reservation/presentation/reservation_list_page.dart';
import 'package:shadja/features/order/presentation/checkout_page.dart';
import 'package:shadja/features/order/presentation/order_detail_page.dart';
import 'package:shadja/features/order/presentation/payment_success_page.dart';
import 'package:shadja/features/reservation/presentation/reservation_form_page.dart';
import 'package:shadja/features/reservation/presentation/reservation_detail_page.dart';
import 'package:shadja/features/printer_settings/presentation/printer_scan_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final status = auth.status;
      final path = state.matchedLocation;
      const authPaths = ['/splash', '/login', '/register'];
      if (status == AuthStatus.initial) return '/splash';
      if (status == AuthStatus.unauthenticated &&
          !authPaths.contains(path)) {
        return '/login';
      }
      if (status == AuthStatus.authenticated && authPaths.contains(path)) {
        return '/home/kasir';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashPage()),
      GoRoute(path: '/login', builder: (c, s) => const LoginPage()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterPage()),
      // Main shell with nav
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home/kasir',
            pageBuilder: (_, _) => NoOpPage(child: KasirPage()),
            routes: [
              GoRoute(
                path: 'checkout',
                builder: (c, s) => const CheckoutPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/home/orders',
            pageBuilder: (_, _) =>
                NoOpPage(child: OrderHistoryPage()),
            routes: [
              GoRoute(
                path: ':id',
                builder: (c, s) =>
                    OrderDetailPage(orderId: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),
          GoRoute(
            path: '/home/reservations',
            pageBuilder: (_, _) =>
                NoOpPage(child: ReservationListPage()),
            routes: [
              GoRoute(
                path: 'new',
                builder: (c, s) => const ReservationFormPage(),
              ),
              GoRoute(
                path: ':id',
                builder: (c, s) => ReservationDetailPage(
                    reservationId: int.parse(s.pathParameters['id']!)),
              ),
            ],
          ),
          GoRoute(
            path: '/home/printer',
            pageBuilder: (_, _) =>
                NoOpPage(child: PrinterSettingsPage()),
            routes: [
              GoRoute(
                path: 'scan',
                builder: (c, s) => const PrinterScanPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/home/profile',
            pageBuilder: (_, _) => NoOpPage(child: ProfilePage()),
          ),
        ],
      ),
      // Routes outside shell (full-screen)
      GoRoute(
        path: '/payment-success/:id',
        builder: (c, s) => PaymentSuccessPage(
            orderId: int.parse(s.pathParameters['id']!)),
      ),
    ],
  );
});

class NoOpPage<T> extends CustomTransitionPage<T> {
  NoOpPage({required super.child})
      : super(
          transitionsBuilder: (c, a, s, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 200),
        );
}

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);

    return ResponsiveLayout(
      mobile: (c) => Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => _onTap(context, i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.restaurant),
              selectedIcon: Icon(Icons.restaurant, color: AppColors.primary),
              label: 'Kasir',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon:
                  Icon(Icons.assignment_outlined, color: AppColors.primary),
              label: 'Order',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month),
              selectedIcon:
                  Icon(Icons.calendar_month, color: AppColors.primary),
              label: 'Reservasi',
            ),
            NavigationDestination(
              icon: Icon(Icons.print_outlined),
              selectedIcon: Icon(Icons.print_outlined, color: AppColors.primary),
              label: 'Printer',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_outline, color: AppColors.primary),
              label: 'Profil',
            ),
          ],
        ),
      ),
      tabletLandscape: (c) => Scaffold(
        body: Row(
          children: [
            // Side navigation
            Container(
              width: 78,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border:
                    Border(right: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SideNavItem(
                        icon: Icons.restaurant,
                        label: 'Kasir',
                        selected: index == 0,
                        onTap: () => _onTap(context, 0)),
                    _SideNavItem(
                        icon: Icons.assignment_outlined,
                        label: 'Order',
                        selected: index == 1,
                        onTap: () => _onTap(context, 1)),
                    _SideNavItem(
                        icon: Icons.calendar_month,
                        label: 'Reservasi',
                        selected: index == 2,
                        onTap: () => _onTap(context, 2)),
                    _SideNavItem(
                        icon: Icons.print_outlined,
                        label: 'Printer',
                        selected: index == 3,
                        onTap: () => _onTap(context, 3)),
                    const Spacer(),
                    _SideNavItem(
                        icon: Icons.person_outline,
                        label: 'Profil',
                        selected: index == 4,
                        onTap: () => _onTap(context, 4)),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  int _selectedIndex(String location) {
    if (location.startsWith('/home/kasir')) return 0;
    if (location.startsWith('/home/orders')) return 1;
    if (location.startsWith('/home/reservations')) return 2;
    if (location.startsWith('/home/printer')) return 3;
    if (location.startsWith('/home/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home/kasir');
      case 1:
        context.go('/home/orders');
      case 2:
        context.go('/home/reservations');
      case 3:
        context.go('/home/printer');
      case 4:
        context.go('/home/profile');
    }
  }
}

class _SideNavItem extends StatelessWidget {
  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 24,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}