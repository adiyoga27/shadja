import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/cart/cart_provider.dart';
import 'package:shadja/features/order/data/additional_cost_model.dart';
import 'package:shadja/features/order/data/order_repository.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';
import 'package:shadja/features/cart/presentation/cart_item_tile.dart';
import 'package:shadja/features/order/presentation/payment_method_sheet.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/table_slider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  String _orderType = 'dine-in';
  String _discountType = 'rp';
  int? _selectedTableId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  num get _discount {
    final raw = _discountCtrl.text.trim();
    if (raw.isEmpty) return 0;
    final d = num.tryParse(raw.replaceAll(RegExp(r'[^\d]'), ''));
    if (d == null) return 0;
    if (_discountType == 'pct') {
      return (ref.read(cartProvider).subtotal * d / 100).round();
    }
    return d;
  }

  // Biaya tambahan (service charge) diterapkan otomatis pada pesanan,
  // tanpa harus dipilih manual oleh kasir.
  AdditionalCostModel? _additionalCost(List<AdditionalCostModel> costs) {
    if (costs.isEmpty) return null;
    final sorted = [...costs]..sort((a, b) =>
        (a.sortOrder ?? 999).compareTo(b.sortOrder ?? 999));
    return sorted.first;
  }

  num _serviceCharge(List<AdditionalCostModel> costs) {
    final cost = _additionalCost(costs);
    if (cost == null) return 0;
    final base = ref.read(cartProvider).subtotal - _discount;
    return (base * cost.rate / 100).round();
  }

  num _total(List<AdditionalCostModel> costs) =>
      ref.read(cartProvider).subtotal - _discount + _serviceCharge(costs);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_orderType == 'dine-in' && _selectedTableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih meja terlebih dahulu'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;

    final costs = await ref.read(additionalCostsProvider.future).catchError((_) => <AdditionalCostModel>[]);
    final selectedCost = _additionalCost(costs);

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
      customerPhone: null,
      deliveryAddress: _orderType == 'delivery' ? _addressCtrl.text.trim() : null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      discount: _discount,
      restaurantTableId: _orderType == 'dine-in' ? _selectedTableId : null,
      serviceChargeRate: selectedCost?.rate,
      additionalCostId: selectedCost?.id,
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
      if (mounted) context.go('/payment-success/${order.id}');
    }
    ref.read(checkoutProvider.notifier).reset();
  }

  Widget _buildDiscountChip(String label, String type, double paddingEnd) {
    final selected = _discountType == type;
    return Padding(
      padding: EdgeInsets.only(right: paddingEnd),
      child: GestureDetector(
        onTap: () => setState(() => _discountType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
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
          if (_orderType == 'dine-in') ...[
            const SizedBox(height: 16),
            const _SectionTitle(title: 'Pilih Meja'),
            const SizedBox(height: 8),
            _TableSelector(
              selectedId: _selectedTableId,
              onChanged: (id) => setState(() => _selectedTableId = id),
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
                      onNotesTap: () async {
                        final result = await showItemNotesDialog(context, it);
                        if (result != null && context.mounted) {
                          ref.read(cartProvider.notifier).updateNotes(
                                it.menuItem,
                                it.notes,
                                result.isEmpty ? null : result,
                              );
                        }
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
            decoration: InputDecoration(
              labelText: _discountType == 'pct' ? 'Diskon (%)' : 'Diskon (Rp)',
              prefixIcon: const Icon(Icons.local_offer_outlined, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDiscountChip('Rp', 'rp', 4),
                  const SizedBox(width: 4),
                  _buildDiscountChip('%', 'pct', 8),
                ],
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // Biaya tambahan (service charge) — diterapkan otomatis
          Consumer(
            builder: (context, ref, _) {
              final costsAsync = ref.watch(additionalCostsProvider);
              return costsAsync.when(
                data: (costs) {
                  final cost = _additionalCost(costs);
                  if (cost == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.room_service_outlined,
                            size: 18, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Biaya tambahan ${cost.name} (${cost.rate}%) diterapkan otomatis',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                      height: 20,
                      child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2))),
                ),
                error: (_, _) => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(height: 20),

          // Summary
          _SectionTitle(title: 'Ringkasan Pembayaran'),
          const SizedBox(height: 8),
          _PriceRow(label: 'Subtotal', value: Formatters.rupiah(cart.subtotal)),
          if (_discount > 0)
            _PriceRow(
                label: _discountType == 'pct'
                    ? 'Diskon (${_discountCtrl.text.trim()}%)'
                    : 'Diskon',
                value: '- ${Formatters.rupiah(_discount)}',
                color: AppColors.danger),
          Consumer(
            builder: (context, ref, _) {
              final costsAsync = ref.watch(additionalCostsProvider);
              return costsAsync.when(
                data: (costs) {
                  final charge = _serviceCharge(costs);
                  final cost = _additionalCost(costs);
                  if (charge <= 0 || cost == null) {
                    return const SizedBox.shrink();
                  }
                  return _PriceRow(
                    label: '${cost.name} (${cost.rate}%)',
                    value: Formatters.rupiah(charge),
                    color: AppColors.info,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              );
            },
          ),
          const Divider(height: 24),
          Consumer(
            builder: (context, ref, _) {
              final costsAsync = ref.watch(additionalCostsProvider);
              return costsAsync.when(
                data: (costs) => _PriceRow(
                  label: 'Total',
                  value: Formatters.rupiah(_total(costs)),
                  isTotal: true,
                ),
                loading: () => _PriceRow(
                  label: 'Total',
                  value: Formatters.rupiah(cart.subtotal - _discount),
                  isTotal: true,
                ),
                error: (_, _) => _PriceRow(
                  label: 'Total',
                  value: Formatters.rupiah(cart.subtotal - _discount),
                  isTotal: true,
                ),
              );
            },
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
    ('dine-in', 'Dine-in', Icons.restaurant),
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
  const _TableSelector({required this.selectedId, required this.onChanged});

  final int? selectedId;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tablesAsync = ref.watch(tablesProvider);
    return tablesAsync.when(
      data: (tables) {
        if (tables.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada meja.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableSlider(
              tables: tables,
              selectedId: selectedId,
              onSelect: onChanged,
            ),
            if (selectedId == null) ...[
              const SizedBox(height: 8),
              const Text('Pilih meja yang tersedia.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
            height: 20,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Gagal memuat daftar meja. Periksa koneksi.',
                style: TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(tablesProvider),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
