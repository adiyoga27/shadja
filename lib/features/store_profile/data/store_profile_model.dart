class StoreProfileModel {
  const StoreProfileModel({
    required this.id,
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    this.isActive = true,
  });

  final int id;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final bool isActive;

  factory StoreProfileModel.fromJson(Map<String, dynamic> json) =>
      StoreProfileModel(
        id: (json['id'] as num?)?.toInt() ?? 0,
        storeName: json['store_name'] as String? ?? '',
        storeAddress: json['store_address'] as String? ?? '',
        storePhone: json['store_phone'] != null ? '${json['store_phone']}' : '',
        isActive: json['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'store_name': storeName,
        'store_address': storeAddress,
        'store_phone': storePhone,
        'is_active': isActive,
      };
}
