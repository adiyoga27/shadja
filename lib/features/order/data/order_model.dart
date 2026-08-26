num _parseNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

class OrderItemModel {
  OrderItemModel({
    required this.id,
    required this.menuItemId,
    required this.menuItemName,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.itemDiscount,
    this.notes,
  });

  final int id;
  final int menuItemId;
  final String menuItemName; // snapshot nama saat transaksi
  final num price; // snapshot harga satuan saat transaksi
  final int quantity;
  final num? itemDiscount;
  final num subtotal;
  final String? notes;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => OrderItemModel(
        id: (json['id'] as num).toInt(),
        menuItemId: (json['menu_item_id'] as num).toInt(),
        menuItemName: (json['menu_item']?['name'] as String?) ??
            json['item_name'] as String? ??
            'Menu #${json['menu_item_id']}',
        price: json['menu_item']?['price'] != null
            ? _parseNum(json['menu_item']?['price'])
            : _parseNum(json['price']),
        quantity: (json['quantity'] as num).toInt(),
        itemDiscount: json['item_discount'] != null ? _parseNum(json['item_discount']) : null,
        subtotal: _parseNum(json['subtotal']),
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'menu_item_id': menuItemId,
        'quantity': quantity,
        'price': price,
        'subtotal': subtotal,
        'notes': notes,
      };
}

class PaymentModel {
  PaymentModel({
    required this.id,
    required this.orderId,
    required this.method,
    required this.amount,
    this.status = 'pending',
    this.reference,
    this.cashReceived,
    this.change,
  });

  final int id;
  final int orderId;
  final String method;
  final num amount;
  final String status;
  final String? reference;
  final num? cashReceived;
  final num? change;

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: (json['id'] as num).toInt(),
        orderId: (json['order_id'] as num).toInt(),
        method: json['method'] as String,
        amount: _parseNum(json['amount']),
        status: (json['status'] as String?) ?? 'pending',
        reference: json['reference'] as String?,
        cashReceived: json['cash_received'] != null
            ? _parseNum(json['cash_received'])
            : null,
        change:
            json['change'] != null ? _parseNum(json['change']) : null,
      );
}

class OrderModel {
  OrderModel({
    required this.id,
    this.orderNumber,
    required this.orderType,
    required this.orderStatus,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.notes,
    required this.orderItems,
    this.payments = const [],
    this.createdAt,
  });

  final int id;
  final String? orderNumber;
  final String orderType;
  final String orderStatus;
  final num subtotal;
  final num discount;
  final num tax;
  final num total;
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final String? notes;
  final List<OrderItemModel> orderItems;
  final List<PaymentModel> payments;
  final DateTime? createdAt;

  factory OrderModel.fromJson(Map<String, dynamic> json) => OrderModel(
        id: (json['id'] as num).toInt(),
        orderNumber: json['order_number'] as String?,
        orderType: json['order_type'] as String,
        orderStatus: (json['order_status'] as String?) ?? 'baru',
        subtotal: _parseNum(json['subtotal']),
        discount: json['discount'] != null ? _parseNum(json['discount']) : 0,
        tax: json['tax'] != null ? _parseNum(json['tax']) : 0,
        total: _parseNum(json['total']),
        customerName: json['customer_name'] as String?,
        customerPhone: json['customer_phone'] as String?,
        deliveryAddress: json['delivery_address'] as String?,
        notes: json['notes'] as String?,
        orderItems: (json['order_items'] as List<dynamic>?)
                ?.map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        payments: (json['payments'] as List<dynamic>?)
                ?.map((e) => PaymentModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}