int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is num) return value.toInt();
  return 0;
}

class RestaurantTableModel {
  RestaurantTableModel({
    required this.id,
    required this.tableNumber,
    required this.capacity,
    this.status = 'kosong',
  });

  final int id;
  final String tableNumber;
  final int capacity;
  final String status;

  factory RestaurantTableModel.fromJson(Map<String, dynamic> json) =>
      RestaurantTableModel(
        id: (json['id'] as num).toInt(),
        tableNumber: (json['table_number'] ?? json['name'] ?? '').toString(),
        capacity: json['capacity'] != null ? (json['capacity'] as num).toInt() : 0,
        status: (json['status'] as String?) ?? 'kosong',
      );
}

class ReservationModel {
  ReservationModel({
    required this.id,
    required this.restaurantTableId,
    required this.reservationTime,
    required this.guestCount,
    this.status = 'pending',
    this.notes,
    this.restaurantTable,
    this.createdAt,
  });

  final int id;
  final int restaurantTableId;
  final DateTime reservationTime;
  final int guestCount;
  final String status;
  final String? notes;
  final RestaurantTableModel? restaurantTable;
  final DateTime? createdAt;

  factory ReservationModel.fromJson(Map<String, dynamic> json) =>
      ReservationModel(
        id: (json['id'] as num).toInt(),
        restaurantTableId: _parseInt(json['restaurant_table_id']),
        reservationTime:
            DateTime.parse(json['reservation_time'] as String),
        guestCount: _parseInt(json['guest_count']),
        status: (json['status'] as String?) ?? 'pending',
        notes: json['notes'] as String?,
        restaurantTable: json['restaurant_table'] != null
            ? RestaurantTableModel.fromJson(
                json['restaurant_table'] as Map<String, dynamic>)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

/// Meja yang sedang dipakai pelanggan (order dine-in aktif),
/// lengkap dengan nomor invoice (order number) dan nama pemesan.
class OccupiedTableModel {
  OccupiedTableModel({
    required this.orderId,
    required this.tableId,
    required this.tableNumber,
    required this.orderNumber,
    required this.customerName,
    required this.orderStatus,
  });

  final int orderId;
  final int tableId;
  final String tableNumber;
  final String orderNumber;
  final String customerName;
  final String orderStatus;
}