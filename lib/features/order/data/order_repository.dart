import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/network/dio_client.dart';
import 'package:shadja/features/order/data/additional_cost_model.dart';
import 'package:shadja/features/order/data/order_model.dart';

class CreateOrderRequest {
  CreateOrderRequest({
    required this.orderType,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.notes,
    this.discount = 0,
    this.restaurantTableId,
    this.serviceChargeRate,
    this.additionalCostId,
  });

  final String orderType;
  final List<CreateOrderItem> items;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? notes;
  final num discount;
  final int? restaurantTableId;
  final num? serviceChargeRate;
  final int? additionalCostId;
}

class CreateOrderItem {
  CreateOrderItem({
    required this.menuItemId,
    required this.quantity,
    this.notes,
  });

  final int menuItemId;
  final int quantity;
  final String? notes;
}

/// Satu halaman hasil `GET /orders`.
class OrderPage {
  const OrderPage({required this.orders, required this.hasMore, this.total});

  static const int defaultPerPage = 20;

  /// Menerima paginator Laravel (`{data, current_page, last_page}`, dengan
  /// meta di root atau di dalam `meta`) maupun array polos. Array polos berarti
  /// server mengabaikan `page` dan sudah mengirim semua order, jadi tidak ada
  /// halaman berikutnya.
  factory OrderPage.fromResponse(
    dynamic body, {
    required int page,
    required int perPage,
  }) {
    if (body is List) {
      return OrderPage(
        orders: _parse(body),
        hasMore: false,
        total: body.length,
      );
    }
    final map = body as Map<String, dynamic>;
    final list = map['data'] as List<dynamic>;
    final meta = map['meta'] is Map ? map['meta'] as Map : map;
    final lastPage = meta['last_page'] as num?;
    return OrderPage(
      orders: _parse(list),
      // simplePaginate tidak punya last_page: halaman penuh = mungkin ada lagi.
      hasMore: lastPage != null ? page < lastPage : list.length >= perPage,
      total: (meta['total'] as num?)?.toInt(),
    );
  }

  static List<OrderModel> _parse(List<dynamic> list) => list
      .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
      .toList();

  final List<OrderModel> orders;
  final bool hasMore;

  /// Jumlah seluruh order yang cocok di server, bukan hanya di halaman ini.
  final int? total;
}

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  String _extractError(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) {
        if (data['message'] is String) return data['message'];
        if (data['message'] is Map) {
          final first = data['message'].values.first;
          return first is List ? first.first.toString() : first.toString();
        }
        if (data['errors'] is Map) {
          final first = data['errors'].values.first;
          return first is List ? first.first.toString() : first.toString();
        }
      }
    }
    return e.toString();
  }

  Future<List<AdditionalCostModel>> fetchAdditionalCosts() async {
    final response = await _dio.get(ApiEndpoints.additionalCosts);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => AdditionalCostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderPage> fetchOrders({
    int page = 1,
    int perPage = OrderPage.defaultPerPage,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final response = await _dio.get(
      ApiEndpoints.orders,
      queryParameters: {
        'page': page,
        'per_page': perPage,
        if (startDate != null) 'start_date': dateFormat.format(startDate),
        if (endDate != null) 'end_date': dateFormat.format(endDate),
        'status': ?status,
      },
    );
    return OrderPage.fromResponse(response.data, page: page, perPage: perPage);
  }

  Future<OrderModel> fetchOrder(int id) async {
    final response = await _dio.get(ApiEndpoints.order(id));
    return OrderModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<OrderModel> createOrder(CreateOrderRequest req) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.orders,
        data: {
          'order_type': req.orderType,
          'items': req.items
              .map((i) => {
                    'menu_item_id': i.menuItemId,
                    'quantity': i.quantity,
                    if (i.notes != null) 'notes': i.notes,
                  })
              .toList(),
          if (req.customerName != null) 'customer_name': req.customerName,
          if (req.customerPhone != null) 'customer_phone': req.customerPhone,
          if (req.deliveryAddress != null)
            'delivery_address': req.deliveryAddress,
          if (req.notes != null) 'notes': req.notes,
          if (req.discount > 0) 'discount': req.discount,
          if (req.restaurantTableId != null)
            'restaurant_table_id': req.restaurantTableId,
          if (req.serviceChargeRate != null && req.serviceChargeRate! > 0)
            'service_charge_rate': req.serviceChargeRate,
          if (req.additionalCostId != null)
            'additional_cost_id': req.additionalCostId,
        },
      );
      return OrderModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }

  Future<PaymentModel> pay({
    required int orderId,
    required String method,
    required num amount,
    String? reference,
    num? cashReceived,
    num? change,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.paymentCallback,
        data: {
          'order_id': orderId,
          'method': method,
          'amount': amount,
          'cash_received': ?cashReceived,
          'change': ?change,
          'reference': ?reference,
        },
      );
      return PaymentModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }
  Future<OrderModel> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _dio.patch(
        ApiEndpoints.orderStatus(orderId),
        data: {'status': status},
      );
      return OrderModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw Exception(_extractError(e));
    }
  }
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.read(dioClientProvider)),
);
