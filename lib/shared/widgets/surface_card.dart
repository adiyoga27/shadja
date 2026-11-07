import 'package:flutter/material.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/shared/widgets/shimmer.dart';

/// Lebar maksimum konten halaman daftar di layar lebar.
const double kListPageMaxWidth = 1360;

/// Grid kartu yang menyesuaikan lebar: 1 kolom di HP, 2–3 kolom di desktop.
/// Tinggi ikut skala teks sistem agar isi kartu tidak overflow.
SliverGridDelegate cardGridDelegate(
  BuildContext context, {
  required double height,
}) =>
    SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 440,
      mainAxisExtent: MediaQuery.textScalerOf(context).scale(height),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );

/// Kartu putih bergaris tepi dengan efek hover dan tap.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.primaryBg,
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

/// Kotak berwarna lembut di sisi kiri kartu (ikon, jam, atau nomor meja).
class TintBox extends StatelessWidget {
  const TintBox({
    super.key,
    required this.color,
    required this.child,
    this.size = 46,
  });

  final Color color;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: FittedBox(fit: BoxFit.scaleDown, child: child),
    );
  }
}

/// Placeholder grid kartu selama data dimuat.
class CardGridSkeleton extends StatelessWidget {
  const CardGridSkeleton({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: cardGridDelegate(context, height: height),
      itemCount: 9,
      itemBuilder: (_, _) => Shimmer(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.shimmerBase,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
