import 'package:flutter/material.dart';

class ShellDrawerScope extends InheritedWidget {
  const ShellDrawerScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static ShellDrawerScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellDrawerScope>();

  @override
  bool updateShouldNotify(ShellDrawerScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}

class ShellDrawerButton extends StatelessWidget {
  const ShellDrawerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = ShellDrawerScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.menu, size: 22),
      tooltip: 'Buka menu',
      onPressed: scope.openDrawer,
    );
  }
}
