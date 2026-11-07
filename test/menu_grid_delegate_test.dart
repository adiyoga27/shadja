import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadja/features/menu/presentation/kasir_page.dart';

SliverGridRegularTileLayout layoutFor(double width) {
  final constraints = SliverConstraints(
    axisDirection: AxisDirection.down,
    growthDirection: GrowthDirection.forward,
    userScrollDirection: ScrollDirection.idle,
    scrollOffset: 0,
    precedingScrollExtent: 0,
    overlap: 0,
    remainingPaintExtent: 800,
    crossAxisExtent: width,
    crossAxisDirection: AxisDirection.right,
    viewportMainAxisExtent: 800,
    remainingCacheExtent: 800,
    cacheOrigin: 0,
  );
  return const MenuGridDelegate(infoHeight: 98).getLayout(constraints)
      as SliverGridRegularTileLayout;
}

void main() {
  test('jumlah kolom mengikuti lebar, minimal 2', () {
    expect(layoutFor(256).crossAxisCount, 2);
    expect(layoutFor(366).crossAxisCount, 2);
    expect(layoutFor(744).crossAxisCount, 4);
    expect(layoutFor(1450).crossAxisCount, 7);
  });

  test('lebar kartu tidak melewati batas maksimum', () {
    for (final width in [366.0, 464.0, 744.0, 1100.0, 1450.0]) {
      expect(
        layoutFor(width).childCrossAxisExtent,
        lessThanOrEqualTo(MenuGridDelegate.maxTileWidth),
      );
    }
  });

  test('area gambar selalu proporsional dengan lebar kartu', () {
    for (final width in [256.0, 366.0, 744.0]) {
      final layout = layoutFor(width);
      expect(
        layout.childMainAxisExtent - 98,
        closeTo(
          layout.childCrossAxisExtent * MenuGridDelegate.imageRatio,
          0.01,
        ),
      );
    }
  });
}
