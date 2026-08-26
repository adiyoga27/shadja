import 'package:flutter/material.dart';

/// Kontrol show/hide sidebar pada layout tablet (lebar layar besar).
/// Identitas instance-nya stabil agar InheritedWidget tidak memicu
/// notifikasi berulang (mencegah error "mutated in performLayout").
class SidebarController extends ChangeNotifier {
  bool _visible = true;
  bool get visible => _visible;

  void toggle() {
    _visible = !_visible;
    notifyListeners();
  }
}

/// Scope agar tombol hamburger di halaman dalam shell bisa membuka drawer
/// (mobile) atau men-toggle sidebar (tablet). Menerima objek dengan identitas
/// stabil (GlobalKey / SidebarController), bukan closure — closure baru setiap
/// build akan memicu notifikasi InheritedWidget saat layout dan merusak pohon
/// render (error "mutated in performLayout") serta membuat tombol tak responsif.
class ShellDrawerScope extends InheritedWidget {
  const ShellDrawerScope({
    super.key,
    this.scaffoldKey,
    this.sidebarController,
    required super.child,
  });

  final GlobalKey<ScaffoldState>? scaffoldKey;
  final SidebarController? sidebarController;

  static ShellDrawerScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellDrawerScope>();

  @override
  bool updateShouldNotify(ShellDrawerScope oldWidget) =>
      scaffoldKey != oldWidget.scaffoldKey ||
      sidebarController != oldWidget.sidebarController;
}

class ShellDrawerButton extends StatelessWidget {
  const ShellDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ShellDrawerScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();

    final controller = scope.sidebarController;
    if (scope.scaffoldKey != null) {
      return IconButton(
        icon: const Icon(Icons.menu, size: 22),
        tooltip: 'Buka menu',
        onPressed: () => scope.scaffoldKey!.currentState?.openDrawer(),
      );
    }
    if (controller != null) {
      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) => IconButton(
          icon: Icon(
            controller.visible ? Icons.menu_open : Icons.menu,
            size: 22,
          ),
          tooltip: 'Tampilkan / sembunyikan menu',
          onPressed: controller.toggle,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}