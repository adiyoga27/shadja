class AdditionalCostModel {
  AdditionalCostModel({
    required this.id,
    required this.name,
    this.rate = 0,
    this.sortOrder,
  });

  final int id;
  final String name;
  final num rate;
  final int? sortOrder;

  factory AdditionalCostModel.fromJson(Map<String, dynamic> json) =>
      AdditionalCostModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? 'Biaya',
        rate: json['rate'] != null ? _parseNum(json['rate']) : 0,
        sortOrder: json['sort_order'] != null
            ? (json['sort_order'] as num).toInt()
            : null,
      );

  static num _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? 0;
    return 0;
  }
}