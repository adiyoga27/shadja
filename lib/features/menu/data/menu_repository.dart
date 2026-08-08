import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/api_endpoints.dart';
import 'package:shadja/core/network/dio_client.dart';
import 'package:shadja/features/menu/data/menu_model.dart';

class MenuRepository {
  MenuRepository(this._dio);

  final Dio _dio;

  Future<List<MenuCategoryModel>> fetchMenu() async {
    final response = await _dio.get(ApiEndpoints.menu);
    final list = response.data as List<dynamic>;
    final cats = list
        .map((e) => MenuCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return cats;
  }

  Future<MenuItemModel> fetchMenuItem(int id) async {
    final response = await _dio.get(ApiEndpoints.menuItem(id));
    return MenuItemModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.read(dioClientProvider)),
);
