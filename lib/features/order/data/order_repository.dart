import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/network/dio_client.dart';
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
  });

  final String orderType;
  final List<CreateOrderItem> items;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? notes;
  final num discount;
  final int? restaurantTableId;
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

  Future<List<OrderModel>> fetchOrders() async {
    final response = await _dio.get(ApiEndpoints.orders);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => OrderModel.fromJson(e as Map<String, dynamic>))
        .toList();
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
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.paymentCallback,
        data: {
          'order_id': orderId,
          'method': method,
          'amount': amount,
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
