import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/cart/cart_provider.dart';
import 'package:shadja/features/order/data/order_repository.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';
import 'package:shadja/features/cart/presentation/cart_item_tile.dart';
import 'package:shadja/features/order/presentation/payment_method_sheet.dart';
import 'package:shadja/features/reservation/data/reservation_repository.dart';
import 'package:shadja/features/reservation/data/reservation_model.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  String _orderType = 'dine_in';
  int? _selectedTableId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  num get _discount {
    final d = num.tryParse(_discountCtrl.text.replaceAll(RegExp(r'[^\d]'), ''));
    return d ?? 0;
  }

  num get _total => ref.read(cartProvider).subtotal - _discount;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final req = CreateOrderRequest(
      orderType: _orderType,
      items: cart.items
          .map((e) => CreateOrderItem(
                menuItemId: e.menuItem.id,
                quantity: e.quantity,
                notes: e.notes,
              ))
          .toList(),
      customerName: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      customerPhone:
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      deliveryAddress: _orderType == 'delivery' ? _addressCtrl.text.trim() : null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      discount: _discount,
      restaurantTableId: _orderType == 'dine_in' ? _selectedTableId : null,
    );

    final order = await ref.read(checkoutProvider.notifier).submit(req);
    if (order == null || !mounted) {
      final err = ref.read(checkoutProvider).error;
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err), backgroundColor: AppColors.danger));
      }
      return;
    }

    final payment = await showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: !order.payments.isNotEmpty,
      builder: (_) => PaymentMethodSheet(order: order),
    );

    if (payment != null && payment.success && mounted) {
      ref.read(cartProvider.notifier).clear();
      ref.read(orderHistoryProvider.notifier).load();
      context.go('/payment-success/${order.id}');
    }
    ref.read(checkoutProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final checkout = ref.watch(checkoutProvider);

    return ResponsiveLayout(
      mobile: (c) => _buildScaffold(c, cart, checkout),
      tabletLandscape: (c) => _buildScaffold(c, cart, checkout, wide: true),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    CartState cart,
    CheckoutState checkout, {
    bool wide = false,
  }) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: wide
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _buildForm(context, cart, checkout),
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildForm(context, cart, checkout),
              ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, CartState cart, CheckoutState co) {
    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('Keranjang masih kosong'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/home/kasir'),
              child: const Text('Kembali ke Kasir'),
            ),
          ],
        ),
      );
    }
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order type selector
          _SectionTitle(title: 'Tipe Pesanan'),
          const SizedBox(height: 8),
          _OrderTypeSelector(
            value: _orderType,
            onChanged: (v) => setState(() => _orderType = v),
          ),
          const SizedBox(height: 20),

          // Customer info
          _SectionTitle(title: 'Data Pelanggan'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Pelanggan',
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Nama wajib diisi'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'No. Telepon (opsional)',
              prefixIcon: Icon(Icons.phone_outlined, size: 18),
            ),
          ),
          if (_orderType == 'dine_in') ...[
            const SizedBox(height: 12),
            _TableSelector(
              onChanged: (id) => _selectedTableId = id,
            ),
          ],
          if (_orderType == 'delivery') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat Pengiriman',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Alamat wajib diisi untuk delivery'
                  : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Catatan (opsional)',
              prefixIcon: Icon(Icons.note_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          // Items review
          _SectionTitle(title: 'Pesanan (${cart.totalQuantity} item)'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final it in cart.items) ...[
                    CartItemTile(
                      item: it,
                      onIncrement: () => ref
                          .read(cartProvider.notifier)
                          .increment(it.menuItem, notes: it.notes),
                      onDecrement: () => ref
                          .read(cartProvider.notifier)
                          .decrement(it.menuItem, notes: it.notes),
                      onRemove: () {
                        final idx = cart.items.indexOf(it);
                        ref.read(cartProvider.notifier).removeItem(idx);
                      },
                    ),
                    if (it != cart.items.last)
                      const Divider(color: AppColors.border, height: 1),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Discount
          TextFormField(
            controller: _discountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Diskon (Rp)',
              prefixIcon: Icon(Icons.local_offer_outlined, size: 18),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),

          // Summary
          _SectionTitle(title: 'Ringkasan Pembayaran'),
          const SizedBox(height: 8),
          _PriceRow(label: 'Subtotal', value: Formatters.rupiah(cart.subtotal)),
          if (_discount > 0)
            _PriceRow(
                label: 'Diskon',
                value: '- ${Formatters.rupiah(_discount)}',
                color: AppColors.danger),
          const Divider(height: 24),
          _PriceRow(
            label: 'Total',
            value: Formatters.rupiah(_total),
            isTotal: true,
          ),
          const SizedBox(height: 20),

          FilledButton.icon(
            onPressed: co.isLoading ? null : _submit,
            icon: co.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 18),
            label: Text(co.isLoading ? 'Memproses…' : 'Buat Order & Bayar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.color,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.normal,
              color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isTotal ? AppColors.primary : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeSelector extends StatelessWidget {
  const _OrderTypeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = [
    ('dine_in', 'Dine-in', Icons.restaurant),
    ('pickup', 'Pickup', Icons.shopping_bag_outlined),
    ('delivery', 'Delivery', Icons.pedal_bike),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((o) {
        final selected = value == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryBg : AppColors.surface,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(o.$3,
                        size: 22,
                        color: selected ? AppColors.primary : AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(
                      o.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TableSelector extends ConsumerWidget {
  const _TableSelector({required this.onChanged});

  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    return tablesAsync.when(
      data: (tables) {
        final available = tables.where((t) => t.status == 'kosong').toList();
        if (available.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Tidak ada meja kosong.',
                style: TextStyle(color: AppColors.danger, fontSize: 13)),
          );
        }
        return DropdownButtonFormField<int>(
          decoration: const InputDecoration(
            labelText: 'Pilih Meja',
            prefixIcon: Icon(Icons.table_bar_outlined, size: 18),
          ),
          items: available
              .map((t) => DropdownMenuItem(
                    value: t.id,
                    child: Text('Meja ${t.tableNumber} (${t.capacity} org)'),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          validator: (v) => v == null ? 'Pilih meja' : null,
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            height: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
