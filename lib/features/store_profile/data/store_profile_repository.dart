import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/network/dio_client.dart';
import 'package:shadja/features/store_profile/data/store_profile_model.dart';

class StoreProfileRepository {
  StoreProfileRepository(this._dio);

  final Dio _dio;

  Future<StoreProfileModel?> fetch() async {
    try {
      final response = await _dio.get(ApiEndpoints.storeProfiles);
      return StoreProfileModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<StoreProfileModel> save({
    required String storeName,
    required String storeAddress,
    required String storePhone,
    bool isActive = true,
  }) async {
    // PUT = create bila belum ada, update bila sudah ada
    final response = await _dio.put(
      ApiEndpoints.storeProfiles,
      data: {
        'store_name': storeName,
        'store_address': storeAddress,
        'store_phone': storePhone,
        'is_active': isActive,
      },
    );
    return StoreProfileModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final storeProfileRepositoryProvider = Provider<StoreProfileRepository>(
  (ref) => StoreProfileRepository(ref.read(dioClientProvider)),
);
