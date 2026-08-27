import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Builds different widget trees based on screen width.
/// - <600  → mobile
/// - 600–1024 → tablet
/// - >=1024 → tabletLandscape (default utama untuk POS)
///
/// CATATAN: cabang dipilih lewat `MediaQuery` pada fase build biasa, BUKAN
/// `LayoutBuilder`. Membangun pohon di dalam builder `LayoutBuilder` terjadi
/// saat fase layout (performLayout) dan rawan memicu loop layout tak berujung
/// ("PipelineOwner.flushLayout" / "_shouldMergeDirtyNodes") terutama saat
/// ukuran layar berubah (mis. maximize jendela desktop) atau saat ada
/// dependensi InheritedWidget/provider di dalam subtree-nya.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.tabletLandscape,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder tabletLandscape;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < Breakpoints.mobile) {
      return mobile(context);
    } else if (width < Breakpoints.tablet) {
      return (tablet ?? mobile)(context);
    }
    return tabletLandscape(context);
  }
}

/// Helper to query the current device form factor.
enum DeviceType { mobile, tablet, tabletLandscape }

DeviceType deviceTypeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.mobile) return DeviceType.mobile;
  if (width < Breakpoints.tablet) return DeviceType.tablet;
  return DeviceType.tabletLandscape;
}

bool isMobile(BuildContext context) => deviceTypeOf(context) == DeviceType.mobile;
bool isTabletLandscape(BuildContext context) =>
    deviceTypeOf(context) == DeviceType.tabletLandscape;