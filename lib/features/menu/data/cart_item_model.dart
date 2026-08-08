import 'package:shadja/features/menu/data/menu_model.dart';

/// Cart item is a local-only state (not from API).
class CartItemModel {
  CartItemModel({
    required this.menuItem,
    this.quantity = 1,
    this.notes,
  });

  final MenuItemModel menuItem;
  final int quantity;
  final String? notes;

  num get lineTotal => menuItem.price * quantity;

  CartItemModel copyWith({
    MenuItemModel? menuItem,
    int? quantity,
    String? notes,
  }) =>
      CartItemModel(
        menuItem: menuItem ?? this.menuItem,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
      );

  CartItemModel copyWithNotes(String? notes) => CartItemModel(
        menuItem: menuItem,
        quantity: quantity,
        notes: notes,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartItemModel &&
          other.menuItem.id == menuItem.id &&
          other.notes == notes);

  @override
  int get hashCode => Object.hash(menuItem.id, notes);
}