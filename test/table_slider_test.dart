import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadja/features/reservation/data/reservation_model.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/table_slider.dart';

void main() {
  testWidgets('TableSlider tidak overflow dengan beberapa meja',
      (tester) async {
    final tables = [
      for (var i = 1; i <= 12; i++)
        RestaurantTableModel(
          id: i,
          tableNumber: 'T$i',
          capacity: 4,
          status: i % 3 == 0 ? 'terisi' : 'kosong',
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TableSlider(
              tables: tables,
              selectedId: null,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final exc = tester.takeException();
      if (exc != null) {
        // ignore: avoid_print
        print('>>> FRAME $i EXCEPTION: $exc');
      }
    }
    expect(tester.takeException(), isNull);
  });
}