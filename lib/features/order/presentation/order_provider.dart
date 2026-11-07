import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/features/order/data/additional_cost_model.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/order/data/order_repository.dart';

final additionalCostsProvider =
    FutureProvider<List<AdditionalCostModel>>((ref) async {
  return ref.read(orderRepositoryProvider).fetchAdditionalCosts();
});

class OrderHistoryState {
  const OrderHistoryState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
    this.filterStatus = 'baru',
    this.searchQuery = '',
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreError,
    this.dateRange,
    this.total,
  });

  /// Order yang sudah dimuat. Status dan tanggal sudah difilter oleh server.
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;
  final String filterStatus;
  final String searchQuery;

  /// Halaman terakhir yang sudah dimuat.
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  /// Dipisah dari [error] supaya gagal memuat halaman berikutnya tidak
  /// mengganti daftar yang sudah tampil dengan layar error.
  final String? loadMoreError;

  /// Filter tanggal di server. Hanya berlaku di tab Semua.
  final DateTimeRange? dateRange;

  /// Jumlah seluruh order di tab aktif menurut server.
  final int? total;

  OrderHistoryState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? error,
    String? filterStatus,
    String? searchQuery,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    DateTimeRange? dateRange,
    bool clearDateRange = false,
    int? total,
  }) =>
      OrderHistoryState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        filterStatus: filterStatus ?? this.filterStatus,
        searchQuery: searchQuery ?? this.searchQuery,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreError: loadMoreError,
        dateRange: clearDateRange ? null : dateRange ?? this.dateRange,
        total: total ?? this.total,
      );
}

class OrderHistoryNotifier extends StateNotifier<OrderHistoryState> {
  OrderHistoryNotifier(this._repo) : super(const OrderHistoryState(isLoading: true));

  final OrderRepository _repo;

  // Naik setiap load(), supaya respons lama yang datang terlambat dibuang.
  int _generation = 0;

  Future<OrderPage> _fetch({int page = 1}) => _repo.fetchOrders(
        page: page,
        startDate: state.dateRange?.start,
        endDate: state.dateRange?.end,
        status: state.filterStatus == 'all' ? null : state.filterStatus,
      );

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    try {
      final result = await _fetch();
      if (generation != _generation) return;
      // Tab dan pencarian tetap tampil saat refresh, jadi nilainya dipertahankan.
      state = OrderHistoryState(
        orders: result.orders,
        hasMore: result.hasMore,
        filterStatus: state.filterStatus,
        searchQuery: state.searchQuery,
        dateRange: state.dateRange,
        total: result.total,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final generation = _generation;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _fetch(page: nextPage);
      if (generation != _generation) return;
      // Order baru menggeser isi halaman, jadi item bisa muncul dua kali.
      final loadedIds = state.orders.map((o) => o.id).toSet();
      state = state.copyWith(
        orders: [
          ...state.orders,
          ...result.orders.where((o) => !loadedIds.contains(o.id)),
        ],
        page: nextPage,
        hasMore: result.hasMore,
        isLoadingMore: false,
        total: result.total,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, loadMoreError: e.toString());
    }
  }

  Future<bool> updateStatus(int orderId, String status) async {
    try {
      await _repo.updateOrderStatus(orderId, status);
      await load();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<void> setFilter(String status) async {
    if (status == state.filterStatus) return;
    // Filter tanggal hanya tersedia di tab Semua.
    state = state.copyWith(
      filterStatus: status,
      clearDateRange: status != 'all',
    );
    await load();
  }

  Future<void> setDateRange(DateTimeRange? range) {
    state = state.copyWith(dateRange: range, clearDateRange: range == null);
    return load();
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final orderHistoryProvider =
    StateNotifierProvider<OrderHistoryNotifier, OrderHistoryState>(
  (ref) {
    final notifier = OrderHistoryNotifier(ref.read(orderRepositoryProvider));
    notifier.load();
    return notifier;
  },
);

final orderDetailProvider =
    FutureProvider.family<OrderModel, int>((ref, id) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.fetchOrder(id);
});

class CheckoutState {
  CheckoutState({this.isLoading = false, this.error, this.createdOrder});

  final bool isLoading;
  final String? error;
  final OrderModel? createdOrder;
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  CheckoutNotifier(this._repo) : super(CheckoutState());

  final OrderRepository _repo;

  Future<(OrderModel, PaymentModel)?> createAndPay({
    required CreateOrderRequest request,
    required String method,
    String? reference,
    num? cashReceived,
    num? change,
  }) async {
    state = CheckoutState(isLoading: true);
    try {
      final order = await _repo.createOrder(request);
      final payment = await _repo.pay(
        orderId: order.id,
        method: method,
        amount: order.total,
        reference: reference,
        cashReceived: cashReceived,
        change: change,
      );
      state = CheckoutState(createdOrder: order);
      return (order, payment);
    } catch (e) {
      state = CheckoutState(error: e.toString());
      return null;
    }
  }

  void reset() => state = CheckoutState();
}

final checkoutProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>(
  (ref) => CheckoutNotifier(ref.read(orderRepositoryProvider)),
);