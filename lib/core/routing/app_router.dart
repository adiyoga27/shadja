import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/features/auth/data/auth_model.dart';
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
  // CATATAN: GoRouter hanya dibuat SEKALI. Membuat GoRouter baru setiap ada
  // perubahan state (mis. `ref.watch(authProvider)` di sini) akan membuat dua
  // Navigator dengan GlobalKey yang sama di pohon widget → error
  // "A GlobalKey can only be specified on one widget at a time" dan freeze.
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      // Dibaca saat navigasi/refresh, bukan watch — router tetap stabil.
      final auth = ref.read(authProvider);
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

  // Saat status auth berubah (login/logout/sesi berakhir), jalankan ulang
  // redirect lewat `refresh()` — tanpa membuat GoRouter baru.
  ref.listen(authProvider, (prev, next) {
    if (prev?.status != next.status) {
      router.refresh();
    }
  });

  return router;
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
    final auth = ref.watch(authProvider);
    final location = GoRouterState.of(context).matchedLocation;
    final index = _selectedIndex(location);

    return ResponsiveLayout(
      mobile: (c) => Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context, index, auth.user),
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
              // Side navigation modern (bisa disembunyikan via tombol hamburger)
              ListenableBuilder(
                listenable: _sidebarCtrl,
                builder: (context, _) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: _sidebarCtrl.visible ? _SideNav.width : 0,
                  clipBehavior: Clip.hardEdge,
                  decoration: const BoxDecoration(
                    gradient: _SideNav.gradient,
                  ),
                  // Konten dipatok pada lebar tetap lalu di-clip saat
                  // sidebar menutup — tidak ada penyempitan yang menyebabkan
                  // overflow baris di dalamnya.
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: _SideNav.width,
                    maxWidth: _SideNav.width,
                    child: SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          const _SideNavBrand(),
                          const SizedBox(height: 22),
                          _SideNavItem(
                              icon: Icons.point_of_sale,
                              label: 'Kasir',
                              selected: index == 0,
                              onTap: () => _onTap(context, 0)),
                          _SideNavItem(
                              icon: Icons.receipt_long_outlined,
                              label: 'Order',
                              selected: index == 1,
                              onTap: () => _onTap(context, 1)),
                          _SideNavItem(
                              icon: Icons.event_note_outlined,
                              label: 'Reservasi',
                              selected: index == 2,
                              onTap: () => _onTap(context, 2)),
                          _SideNavItem(
                              icon: Icons.print_outlined,
                              label: 'Printer',
                              selected: index == 3,
                              onTap: () => _onTap(context, 3)),
                          const Spacer(),
                          Container(
                            height: 1,
                            margin:
                                const EdgeInsets.symmetric(horizontal: 20),
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                          const SizedBox(height: 14),
                          _SideNavProfile(
                            user: auth.user,
                            selected: index == 4,
                            onTap: () => _onTap(context, 4),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
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

  Widget _buildDrawer(BuildContext context, int index, UserModel? user) {
    return Drawer(
      width: 292,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(gradient: _SideNav.gradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const _SideNavBrand(),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    _SideNavItem(
                        icon: Icons.point_of_sale,
                        label: 'Kasir',
                        selected: index == 0,
                        onTap: () {
                          Navigator.of(context).pop();
                          _onTap(context, 0);
                        }),
                    _SideNavItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Order',
                        selected: index == 1,
                        onTap: () {
                          Navigator.of(context).pop();
                          _onTap(context, 1);
                        }),
                    _SideNavItem(
                        icon: Icons.event_note_outlined,
                        label: 'Reservasi',
                        selected: index == 2,
                        onTap: () {
                          Navigator.of(context).pop();
                          _onTap(context, 2);
                        }),
                    _SideNavItem(
                        icon: Icons.print_outlined,
                        label: 'Printer',
                        selected: index == 3,
                        onTap: () {
                          Navigator.of(context).pop();
                          _onTap(context, 3);
                        }),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: Colors.white.withValues(alpha: 0.14),
              ),
              const SizedBox(height: 14),
              _SideNavProfile(
                user: user,
                selected: index == 4,
                onTap: () {
                  Navigator.of(context).pop();
                  _onTap(context, 4);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
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

/// Konstanta desain sidebar/drawer (lebar & gradien hijau gelap).
class _SideNav {
  _SideNav._();

  static const double width = 232;
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C3B26), Color(0xFF166534), Color(0xFF15803D)],
    stops: [0.0, 0.55, 1.0],
  );
}

class _SideNavBrand extends StatelessWidget {
  const _SideNavBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.restaurant_menu,
                color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shadja POS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Restaurant Solution',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final fg = selected ? Colors.white : Colors.white.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 4,
                  height: 22,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(icon, size: 21, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: fg,
                    ),
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

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class _SideNavProfile extends StatelessWidget {
  const _SideNavProfile({
    required this.user,
    required this.selected,
    required this.onTap,
  });

  final UserModel? user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'Pengguna';
    final role = (user?.role ?? 'kasir').toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
