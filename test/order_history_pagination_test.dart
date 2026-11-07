import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/order/data/order_repository.dart';
import 'package:shadja/features/order/presentation/order_history_page.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';

Map<String, dynamic> _json(int id) => {
      'id': id,
      'order_type': 'pickup',
      'order_status': 'baru',
      'subtotal': 1000,
      'total': 1000,
      'order_items': <dynamic>[],
    };

OrderModel _order(int id) => OrderModel.fromJson(_json(id));

OrderPage _page(List<int> ids, {required bool hasMore}) =>
    OrderPage(orders: ids.map(_order).toList(), hasMore: hasMore);

class _FakeRepo extends OrderRepository {
  _FakeRepo(this.handler) : super(Dio());

  final Future<OrderPage> Function(int page) handler;
  final requestedPages = <int>[];
  final requestedStarts = <DateTime?>[];
  final requestedStatuses = <String?>[];

  @override
  Future<OrderPage> fetchOrders({
    int page = 1,
    int perPage = OrderPage.defaultPerPage,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) {
    requestedPages.add(page);
    requestedStarts.add(startDate);
    requestedStatuses.add(status);
    return handler(page);
  }
}

void main() {
  group('OrderPage.fromResponse', () {
    OrderPage parse(dynamic body, {int page = 1, int perPage = 2}) =>
        OrderPage.fromResponse(body, page: page, perPage: perPage);

    test('array polos tidak punya halaman berikutnya', () {
      final result = parse([_json(1), _json(2)]);
      expect(result.orders.map((o) => o.id), [1, 2]);
      expect(result.hasMore, isFalse);
    });

    test('paginator Laravel memakai last_page di root', () {
      final body = {
        'data': [_json(1)],
        'current_page': 1,
        'last_page': 3,
      };
      expect(parse(body).hasMore, isTrue);
      expect(parse(body, page: 3).hasMore, isFalse);
    });

    test('API resource memakai last_page di dalam meta', () {
      final body = {
        'data': [_json(1)],
        'meta': {'current_page': 2, 'last_page': 2},
      };
      expect(parse(body, page: 2).hasMore, isFalse);
    });

    test('simplePaginate memakai jumlah item per halaman', () {
      expect(parse({'data': [_json(1), _json(2)]}).hasMore, isTrue);
      expect(parse({'data': [_json(1)]}).hasMore, isFalse);
    });

    test('total diambil dari server, bukan dari isi halaman', () {
      final body = {
        'data': [_json(1)],
        'last_page': 3,
        'total': 45,
      };
      expect(parse(body).total, 45);
      expect(parse([_json(1), _json(2)]).total, 2);
    });
  });

  group('OrderHistoryNotifier', () {
    test('loadMore menambah halaman dan membuang order dobel', () async {
      final repo = _FakeRepo((page) async => page == 1
          ? _page([3, 2], hasMore: true)
          : _page([2, 1], hasMore: false));
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      await notifier.loadMore();

      expect(notifier.state.orders.map((o) => o.id), [3, 2, 1]);
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.page, 2);
    });

    test('backend tanpa pagination hanya menerima satu request', () async {
      final repo = _FakeRepo((_) async => _page([1, 2], hasMore: false));
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      await notifier.loadMore();

      expect(repo.requestedPages, [1]);
      expect(notifier.state.orders, hasLength(2));
    });

    test('loadMore gagal mempertahankan daftar dan bisa diulang', () async {
      var fail = true;
      final repo = _FakeRepo((page) async {
        if (page == 1) return _page([2], hasMore: true);
        if (fail) throw Exception('timeout');
        return _page([1], hasMore: false);
      });
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      await notifier.loadMore();
      expect(notifier.state.error, isNull);
      expect(notifier.state.loadMoreError, isNotNull);
      expect(notifier.state.orders, hasLength(1));

      fail = false;
      await notifier.loadMore();
      expect(notifier.state.loadMoreError, isNull);
      expect(notifier.state.orders.map((o) => o.id), [2, 1]);
    });

    test('filter tetap terpasang setelah loadMore', () async {
      final repo = _FakeRepo((page) async => page == 1
          ? _page([2], hasMore: true)
          : _page([1], hasMore: false));
      final notifier = OrderHistoryNotifier(repo);

      await notifier.setFilter('selesai');
      await notifier.loadMore();

      expect(notifier.state.filterStatus, 'selesai');
      expect(repo.requestedPages, [1, 2]);
      expect(repo.requestedStatuses, ['selesai', 'selesai']);
    });

    test('tab Semua tidak mengirim status', () async {
      final repo = _FakeRepo((_) async => _page([1], hasMore: false));
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      await notifier.setFilter('all');

      expect(repo.requestedStatuses, ['baru', null]);
    });

    test('menekan tab yang sedang aktif tidak memuat ulang', () async {
      final repo = _FakeRepo((_) async => _page([1], hasMore: false));
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      await notifier.setFilter('baru');

      expect(repo.requestedPages, hasLength(1));
    });

    test('respons tab lama dibuang saat pindah tab dengan cepat', () async {
      final slow = Completer<OrderPage>();
      var calls = 0;
      final repo = _FakeRepo((_) {
        calls++;
        return calls == 1
            ? slow.future
            : Future.value(_page([2], hasMore: false));
      });
      final notifier = OrderHistoryNotifier(repo);

      final first = notifier.load();
      await notifier.setFilter('selesai');
      slow.complete(_page([1], hasMore: false));
      await first;

      expect(notifier.state.orders.map((o) => o.id), [2]);
      expect(notifier.state.filterStatus, 'selesai');
    });

    test('tab awal Baru dan tab aktif bertahan setelah refresh', () async {
      final repo = _FakeRepo((_) async => _page([1], hasMore: false));
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      expect(notifier.state.filterStatus, 'baru');

      await notifier.setFilter('selesai');
      await notifier.load();
      expect(notifier.state.filterStatus, 'selesai');
    });

    group('filter tanggal', () {
      final range = DateTimeRange(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 30),
      );

      test('dikirim ke server, termasuk saat loadMore dan refresh', () async {
        final repo = _FakeRepo((_) async => _page([1], hasMore: true));
        final notifier = OrderHistoryNotifier(repo);
        await notifier.setFilter('all');
        repo.requestedStarts.clear();

        await notifier.setDateRange(range);
        await notifier.loadMore();
        await notifier.load();

        expect(repo.requestedStarts, [range.start, range.start, range.start]);
        expect(notifier.state.dateRange, range);
      });

      test('pindah dari tab Semua menghapus filter dan memuat ulang', () async {
        final repo = _FakeRepo((_) async => _page([1], hasMore: false));
        final notifier = OrderHistoryNotifier(repo);
        await notifier.setFilter('all');
        await notifier.setDateRange(range);

        await notifier.setFilter('baru');

        expect(notifier.state.dateRange, isNull);
        expect(repo.requestedStarts.last, isNull);
        expect(repo.requestedStatuses.last, 'baru');
      });

      test('menghapus filter memuat semua order lagi', () async {
        final repo = _FakeRepo((_) async => _page([1], hasMore: false));
        final notifier = OrderHistoryNotifier(repo);
        await notifier.setDateRange(range);

        await notifier.setDateRange(null);

        expect(notifier.state.dateRange, isNull);
        expect(repo.requestedStarts.last, isNull);
      });
    });

    test('parameter dikirim sesuai format API', () async {
      late Map<String, dynamic> query;
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              query = options.queryParameters;
              handler.resolve(
                Response(requestOptions: options, data: <dynamic>[]),
              );
            },
          ),
        );

      await OrderRepository(dio).fetchOrders(
        page: 2,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        status: 'selesai',
      );

      expect(query, {
        'page': 2,
        'per_page': OrderPage.defaultPerPage,
        'start_date': '2026-11-01',
        'end_date': '2026-11-30',
        'status': 'selesai',
      });
    });

    test('hasil loadMore basi dibuang setelah refresh', () async {
      final slowPage2 = Completer<OrderPage>();
      var firstLoad = true;
      final repo = _FakeRepo((page) {
        if (page == 2) return slowPage2.future;
        if (firstLoad) {
          firstLoad = false;
          return Future.value(_page([1], hasMore: true));
        }
        return Future.value(_page([9], hasMore: true));
      });
      final notifier = OrderHistoryNotifier(repo);

      await notifier.load();
      final pending = notifier.loadMore();
      await notifier.load();
      slowPage2.complete(_page([5], hasMore: false));
      await pending;

      expect(notifier.state.orders.map((o) => o.id), [9]);
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.state.isLoadingMore, isFalse);
    });
  });

  testWidgets('filter tanggal hanya muncul di tab Semua', (tester) async {
    final repo = _FakeRepo((_) async => _page([1], hasMore: false));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: OrderHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal'), findsNothing);

    await tester.tap(find.text('Semua'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih tanggal'), findsOneWidget);

    await tester.tap(find.text('Pilih tanggal'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih rentang tanggal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol memuat halaman berikutnya saat daftar pendek',
      (tester) async {
    final repo = _FakeRepo((page) async => page == 1
        ? _page([2], hasMore: true)
        : _page([1], hasMore: false));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [orderRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: OrderHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Order #2'), findsOneWidget);
    expect(find.text('Order #1'), findsNothing);

    await tester.tap(find.text('Muat lebih banyak'));
    await tester.pumpAndSettle();

    expect(find.text('Order #1'), findsOneWidget);
    expect(find.text('Muat lebih banyak'), findsNothing);
  });
}
