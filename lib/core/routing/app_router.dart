import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
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
import 'package:shadja/shared/widgets/shell_drawer_button.dart';

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

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _sidebarCtrl = SidebarController();

  @override
  void initState() {
    super.initState();
    // Ditunda sampai setelah frame pertama agar dialog izin Bluetooth /
    // perubahan inset sistem tidak muncul saat shell sedang di-layout
    // (mencegah "RenderFlex was mutated in performLayout").
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBluetoothPermission());
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkBluetoothPermission() async {
    if (!Platform.isAndroid) return;
    final sdkInt = await PrintBluetoothThermal.platformVersion;
    final sdk = int.tryParse(sdkInt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (sdk < 31) return;

    final perm = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!mounted) return;
    if (!perm) {
      await Permission.bluetoothConnect.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);

    return ResponsiveLayout(
      mobile: (c) => Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context, index),
        body: ShellDrawerScope(
          scaffoldKey: _scaffoldKey,
          child: widget.child,
        ),
      ),
      tabletLandscape: (c) => Scaffold(
        body: ShellDrawerScope(
          sidebarController: _sidebarCtrl,
          child: Row(
            children: [
              // Side navigation (bisa disembunyikan via tombol hamburger)
              ListenableBuilder(
                listenable: _sidebarCtrl,
                builder: (context, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: _sidebarCtrl.visible ? 112 : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border:
                        Border(right: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        const _SideNavLogo(),
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, int index) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary.withValues(alpha: 0.85),
                ),
              ),
            ),
            const Divider(height: 1),
            _DrawerItem(
                icon: Icons.restaurant,
                label: 'Kasir',
                selected: index == 0,
                onTap: () {
                  Navigator.of(context).pop();
                  _onTap(context, 0);
                }),
            _DrawerItem(
                icon: Icons.assignment_outlined,
                label: 'Order',
                selected: index == 1,
                onTap: () {
                  Navigator.of(context).pop();
                  _onTap(context, 1);
                }),
            _DrawerItem(
                icon: Icons.calendar_month,
                label: 'Reservasi',
                selected: index == 2,
                onTap: () {
                  Navigator.of(context).pop();
                  _onTap(context, 2);
                }),
            _DrawerItem(
                icon: Icons.print_outlined,
                label: 'Printer',
                selected: index == 3,
                onTap: () {
                  Navigator.of(context).pop();
                  _onTap(context, 3);
                }),
            _DrawerItem(
                icon: Icons.person_outline,
                label: 'Profil',
                selected: index == 4,
                onTap: () {
                  Navigator.of(context).pop();
                  _onTap(context, 4);
                }),
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

class _SideNavLogo extends StatelessWidget {
  const _SideNavLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.restaurant_menu,
          color: Colors.white, size: 24),
    );
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryBg : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.2,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: selected ? null : AppColors.surfaceAlt,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: selected ? AppColors.primaryBg : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
