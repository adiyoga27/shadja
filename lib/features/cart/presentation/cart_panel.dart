import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/cart/cart_provider.dart';
import 'package:shadja/features/cart/presentation/cart_item_tile.dart';
import 'package:shadja/features/menu/data/cart_item_model.dart';
import 'package:shadja/shared/widgets/empty_state.dart';

class CartPanel extends ConsumerWidget {
  const CartPanel({super.key, this.scrollable = true});

  final bool scrollable;

  Future<void> _editNotes(
      BuildContext context, WidgetRef ref, CartItemModel item) async {
    final result = await showItemNotesDialog(context, item);
    if (result != null && context.mounted) {
      ref.read(cartProvider.notifier).updateNotes(
            item.menuItem,
            result.isEmpty ? null : result,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart_outlined,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Keranjang${cart.totalQuantity > 0 ? ' • ${cart.totalQuantity} item' : ''}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (cart.totalQuantity > 0)
                  TextButton.icon(
                    onPressed: () => ref.read(cartProvider.notifier).clear(),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Kosongkan',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ),
          // Items list
          Expanded(
            child: cart.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Keranjang kosong',
                    subtitle: 'Pilih menu untuk menambahkan ke keranjang.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final it = cart.items[index];
                      return CartItemTile(
                        item: it,
                        onIncrement: () => ref
                            .read(cartProvider.notifier)
                            .increment(it.menuItem, notes: it.notes),
                        onDecrement: () => ref
                            .read(cartProvider.notifier)
                            .decrement(it.menuItem, notes: it.notes),
                        onRemove: () =>
                            ref.read(cartProvider.notifier).removeItem(index),
                        onNotesTap: () => _editNotes(context, ref, it),
                        compact: true,
                      );
                    },
                  ),
          ),
          // Summary + Checkout
          if (cart.totalQuantity > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.textSecondary)),
                      Text(Formatters.rupiah(cart.subtotal),
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => context.go('/home/kasir/checkout'),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('Checkout'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}