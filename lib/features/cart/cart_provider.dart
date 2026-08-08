import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/features/menu/data/cart_item_model.dart';
import 'package:shadja/features/menu/data/menu_model.dart';

class CartState {
  const CartState({this.items = const []});

  final List<CartItemModel> items;

  CartState copyWith({List<CartItemModel>? items}) =>
      CartState(items: items ?? this.items);

  int get totalQuantity => items.fold(0, (sum, e) => sum + e.quantity);
  num get subtotal => items.fold(0, (sum, e) => sum + e.lineTotal);
  bool get isEmpty => items.isEmpty;
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void add(MenuItemModel menu, {int qty = 1, String? notes}) {
    final existingIdx = state.items.indexWhere(
      (e) => e.menuItem.id == menu.id && e.notes == notes,
    );
    if (existingIdx >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      final it = updated[existingIdx];
      updated[existingIdx] = it.copyWith(quantity: it.quantity + qty);
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItemModel(menuItem: menu, quantity: qty, notes: notes),
      ]);
    }
  }

  void increment(MenuItemModel menu, {String? notes}) {
    final idx = state.items
        .indexWhere((e) => e.menuItem.id == menu.id && e.notes == notes);
    if (idx >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      final it = updated[idx];
      updated[idx] = it.copyWith(quantity: it.quantity + 1);
      state = state.copyWith(items: updated);
    }
  }

  void decrement(MenuItemModel menu, {String? notes}) {
    final idx = state.items
        .indexWhere((e) => e.menuItem.id == menu.id && e.notes == notes);
    if (idx >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      final it = updated[idx];
      if (it.quantity > 1) {
        updated[idx] = it.copyWith(quantity: it.quantity - 1);
      } else {
        updated.removeAt(idx);
      }
      state = state.copyWith(items: updated);
    }
  }

  void updateQuantity(MenuItemModel menu, int quantity, {String? notes}) {
    final idx = state.items
        .indexWhere((e) => e.menuItem.id == menu.id && e.notes == notes);
    if (idx >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      if (quantity <= 0) {
        updated.removeAt(idx);
      } else {
        updated[idx] = updated[idx].copyWith(quantity: quantity);
      }
      state = state.copyWith(items: updated);
    }
  }

  void updateNotes(MenuItemModel menu, String? notes) {
    final idx = state.items
        .indexWhere((e) => e.menuItem.id == menu.id && e.notes == notes);
    if (idx >= 0) {
      final updated = List<CartItemModel>.from(state.items);
      updated[idx] = updated[idx].copyWithNotes(notes);
      state = state.copyWith(items: updated);
    }
  }

  void removeItem(int index) {
    final updated = List<CartItemModel>.from(state.items);
    if (index >= 0 && index < updated.length) {
      updated.removeAt(index);
      state = state.copyWith(items: updated);
    }
  }

  void clear() => state = const CartState();
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);