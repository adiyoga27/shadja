import 'package:shadja/core/constants/api_endpoints.dart';

num _parseNum(dynamic value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

String? _imageUrl(String? image) {
  if (image == null || image.isEmpty) return null;
  if (image.startsWith('http://') || image.startsWith('https://')) return image;
  return '${ApiEndpoints.baseUrl}/storage/$image';
}

class MenuItemModel {
  MenuItemModel({
    required this.id,
    required this.name,
    required this.price,
    this.takeawayPrice,
    this.image,
    this.description,
    this.isActive = true,
    this.categoryId,
    this.categoryName,
  });

  final int id;
  final String name;
  final num price;
  /// Harga khusus take away / pesan dibawa pulang (nilai 0/null = pakai [price]).
  final num? takeawayPrice;
  final String? image;
  final String? description;
  final bool isActive;
  final int? categoryId;
  final String? categoryName;

  /// Harga efektif untuk mode take away (jika ada harga khusus).
  num priceForTakeaway() => takeawayPrice ?? price;

  factory MenuItemModel.fromJson(Map<String, dynamic> json) => MenuItemModel(
        id: ((json['id'] as num).toInt()),
        name: json['name'] as String,
        price: _parseNum(json['price']),
        takeawayPrice: json['takeaway_price'] != null
            ? _parseNum(json['takeaway_price'])
            : null,
        image: _imageUrl(json['image'] as String?),
        description: json['description'] as String?,
        isActive: (json['is_active'] as bool?) ?? true,
        categoryId: json['category_id'] != null ? (json['category_id'] as num).toInt() : null,
        categoryName: json['category_name'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'takeaway_price': takeawayPrice,
        'image': image,
        'description': description,
        'is_active': isActive,
      };

  MenuItemModel copyWith({
    int? id,
    String? name,
    num? price,
    num? takeawayPrice,
    String? image,
    String? description,
    bool? isActive,
    int? categoryId,
    String? categoryName,
  }) =>
      MenuItemModel(
        id: id ?? this.id,
        name: name ?? this.name,
        price: price ?? this.price,
        takeawayPrice: takeawayPrice ?? this.takeawayPrice,
        image: image ?? this.image,
        description: description ?? this.description,
        isActive: isActive ?? this.isActive,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
      );
}

class MenuCategoryModel {
  MenuCategoryModel({
    required this.id,
    required this.name,
    this.menuItems = const [],
  });

  final int id;
  final String name;
  final List<MenuItemModel> menuItems;

  factory MenuCategoryModel.fromJson(Map<String, dynamic> json) =>
      MenuCategoryModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String,
        menuItems: (json['menu_items'] as List<dynamic>?)
            ?.map((e) => MenuItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'menu_items': menuItems.map((e) => e.toJson()).toList(),
      };
}