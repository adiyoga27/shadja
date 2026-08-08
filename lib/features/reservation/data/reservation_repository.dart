import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/network/dio_client.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';

class CreateReservationRequest {
  CreateReservationRequest({
    required this.restaurantTableId,
    required this.reservationTime,
    required this.guestCount,
    this.notes,
  });

  final int restaurantTableId;
  final DateTime reservationTime;
  final int guestCount;
  final String? notes;
}

class ReservationRepository {
  ReservationRepository(this._dio);

  final Dio _dio;

  Future<List<ReservationModel>> fetchReservations() async {
    final response = await _dio.get(ApiEndpoints.reservations);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => ReservationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReservationModel> fetchReservation(int id) async {
    final response = await _dio.get(ApiEndpoints.reservation(id));
    return ReservationModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<RestaurantTableModel>> fetchTables() async {
    final response = await _dio.get(ApiEndpoints.tables);
    final list = response.data as List<dynamic>;
    return list
        .map((e) => RestaurantTableModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ReservationModel> create(CreateReservationRequest req) async {
    final response = await _dio.post(
      ApiEndpoints.reservations,
      data: {
        'restaurant_table_id': req.restaurantTableId,
        'reservation_time': req.reservationTime.toIso8601String(),
        'guest_count': req.guestCount,
        if (req.notes != null) 'notes': req.notes,
      },
    );
    return ReservationModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final reservationRepositoryProvider = Provider<ReservationRepository>(
  (ref) => ReservationRepository(ref.read(dioClientProvider)),
);
