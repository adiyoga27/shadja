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
    this.filterStatus = 'all',
    this.searchQuery = '',
  });

  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;
  final String filterStatus;
  final String searchQuery;

  OrderHistoryState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? error,
    String? filterStatus,
    String? searchQuery,
  }) =>
      OrderHistoryState(
        orders: orders ?? this.orders,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        filterStatus: filterStatus ?? this.filterStatus,
        searchQuery: searchQuery ?? this.searchQuery,
      );

  List<OrderModel> get filteredOrders {
    if (filterStatus == 'all') return orders;
    return orders.where((o) => o.orderStatus == filterStatus).toList();
  }
}

class OrderHistoryNotifier extends StateNotifier<OrderHistoryState> {
  OrderHistoryNotifier(this._repo) : super(const OrderHistoryState(isLoading: true));

  final OrderRepository _repo;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final orders = await _repo.fetchOrders();
      state = OrderHistoryState(orders: orders);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
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

  void setFilter(String status) {
    state = state.copyWith(filterStatus: status);
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

  Future<OrderModel?> submit(CreateOrderRequest req) async {
    state = CheckoutState(isLoading: true);
    try {
      final order = await _repo.createOrder(req);
      state = CheckoutState(createdOrder: order);
      return order;
    } catch (e) {
      state = CheckoutState(error: e.toString());
      return null;
    }
  }

  Future<PaymentModel?> pay({
    required int orderId,
    required String method,
    required num amount,
    String? reference,
    num? cashReceived,
    num? change,
  }) async {
    state = CheckoutState(isLoading: true);
    try {
      final payment = await _repo.pay(
        orderId: orderId,
        method: method,
        amount: amount,
        reference: reference,
        cashReceived: cashReceived,
        change: change,
      );
      state = CheckoutState(createdOrder: state.createdOrder);
      return payment;
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