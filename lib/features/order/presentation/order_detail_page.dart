import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/responsive/responsive_layout.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';
import 'package:shadja/features/printer/presentation/print_dialog.dart';
import 'package:shadja/features/reservation/presentation/reservation_provider.dart';
import 'package:shadja/shared/widgets/loading_state.dart';
import 'package:shadja/shared/widgets/status_badge.dart';

class OrderDetailPage extends ConsumerWidget {
  const OrderDetailPage({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Order'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ResponsiveLayout(
        mobile: (_) => _body(context, ref, orderAsync),
        tabletLandscape: (_) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: _body(context, ref, orderAsync),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<OrderModel> orderAsync,
  ) {
    return orderAsync.when(
      loading: () => const Center(child: LoadingState()),
      error: (e, _) => ErrorState(message: 'Gagal memuat: $e'),
      data: (order) => _buildDetail(context, ref, order),
    );
  }

  Widget _buildDetail(BuildContext context, WidgetRef ref, OrderModel order) {
    final badge = _statusBadge(order.orderStatus);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          order.orderNumber ?? 'Order #${order.id}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      StatusBadge(label: badge.$2, status: badge.$1),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _InfoRow(
                      icon: Icons.pedal_bike,
                      label: 'Tipe',
                      value: _orderTypeLabel(order.orderType)),
                  if (order.customerName != null)
                    _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Pelanggan',
                        value: order.customerName!),
                  if (order.customerPhone != null)
                    _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Telepon',
                        value: order.customerPhone!),
                  if (order.deliveryAddress != null)
                    _InfoRow(
                        icon: Icons.location_on_outlined,
                        label: 'Alamat',
                        value: order.deliveryAddress!),
                  if (order.createdAt != null)
                    _InfoRow(
                        icon: Icons.access_time,
                        label: 'Waktu',
                        value: Formatters.dateTime(order.createdAt!)),
                  if (order.notes != null && order.notes!.isNotEmpty)
                    _InfoRow(
                        icon: Icons.note_outlined,
                        label: 'Catatan',
                        value: order.notes!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items
          const Text('Item Pesanan',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (final item in order.orderItems) ...[
                    _ItemRow(
                      item: item,
                      isTakeaway: order.orderType == 'pickup',
                    ),
                    if (item != order.orderItems.last)
                      const Divider(color: AppColors.border, height: 1),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PriceRow(label: 'Subtotal', value: Formatters.rupiah(order.subtotal)),
                  if (order.additionalCost > 0)
                    _PriceRow(
                        label: _costLabel(order),
                        value: '+ ${Formatters.rupiah(order.additionalCost)}',
                        color: AppColors.info),
                  if (order.discount > 0)
                    _PriceRow(
                        label: 'Diskon',
                        value: '- ${Formatters.rupiah(order.discount)}',
                        color: AppColors.danger),
                  if (order.tax > 0)
                    _PriceRow(
                        label: 'Pajak',
                        value: '+ ${Formatters.rupiah(order.tax)}',
                        color: AppColors.warning),
                  const Divider(height: 24),
                  _PriceRow(
                      label: 'Total',
                      value: Formatters.rupiah(order.total),
                      isTotal: true),
                ],
              ),
            ),
          ),
          if (order.payments.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Pembayaran',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final p in order.payments) ...[
                      _PriceRow(
                        label: p.method.toUpperCase(),
                        value: Formatters.rupiah(p.amount),
                      ),
                      if (p.cashReceived != null)
                        _PriceRow(
                          label: 'Tunai diterima',
                          value: Formatters.rupiah(p.cashReceived!),
                        ),
                      if (p.change != null && p.change! > 0)
                        _PriceRow(
                          label: 'Kembalian',
                          value: Formatters.rupiah(p.change!),
                          color: AppColors.success,
                        ),
                      if (p.reference != null)
                        _InfoRow(
                            icon: Icons.tag,
                            label: 'Ref',
                            value: p.reference!),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Progress action buttons
          if (order.orderStatus != 'selesai' && order.orderStatus != 'dibatalkan') ...[
            const Text('Update Status',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            _ProgressButtons(order: order),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async =>
                      PrintDialog.show(context, order: order),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Cetak Struk'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/home/kasir'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Order Baru'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  (BadgeStatus, String) _statusBadge(String status) {
    switch (status) {
      case 'selesai':
        return (BadgeStatus.success, 'Selesai');
      case 'siap':
        return (BadgeStatus.success, 'Siap');
      case 'diproses':
        return (BadgeStatus.warning, 'Diproses');
      case 'dibatalkan':
        return (BadgeStatus.danger, 'Dibatalkan');
      default:
        return (BadgeStatus.info, 'Baru');
    }
  }

  static String _rateText(num? rate) {
    if (rate == null) return '';
    final r = rate.toDouble();
    final text = r == r.roundToDouble() ? r.toInt().toString() : r.toString();
    return ' ($text%)';
  }

  static String _costLabel(OrderModel order) =>
      '${order.additionalCostName ?? 'Biaya Tambahan'}${_rateText(order.additionalCostRate)}';

  String _orderTypeLabel(String type) {
    switch (type) {
      case 'dine-in':
        return 'Dine-in';
      case 'pickup':
        return 'Take Away';
      case 'delivery':
        return 'Delivery';
      default:
        return type;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textHint),
          const SizedBox(width: 6),
          Text('$label:',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, this.isTakeaway = false});
  final OrderItemModel item;
  final bool isTakeaway;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}×',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.menuItemName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text(
                  isTakeaway
                      ? 'Take Away • ${Formatters.rupiah(item.price)}'
                      : Formatters.rupiah(item.price),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isTakeaway ? FontWeight.w600 : FontWeight.w400,
                    color: isTakeaway
                        ? AppColors.info
                        : AppColors.textSecondary,
                  ),
                ),
                if (item.notes != null && item.notes!.isNotEmpty)
                  Text(
                    '📝 ${item.notes}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.warning),
                  ),
              ],
            ),
          ),
          Text(
            Formatters.rupiah(item.subtotal),
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
        ],
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
          Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight:
                      isTotal ? FontWeight.w700 : FontWeight.normal,
                  color: isTotal
                      ? AppColors.textPrimary
                      : AppColors.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: isTotal ? 18 : 14,
                  fontWeight:
                      isTotal ? FontWeight.bold : FontWeight.w600,
                  color: color ??
                      (isTotal ? AppColors.primary : AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _ProgressButtons extends ConsumerStatefulWidget {
  const _ProgressButtons({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_ProgressButtons> createState() => _ProgressButtonsState();
}

class _ProgressButtonsState extends ConsumerState<_ProgressButtons> {
  bool _updating = false;

  (String, String)? get _nextAction => switch (widget.order.orderStatus) {
        'baru' => ('diproses', 'Proses Pesanan'),
        'diproses' => ('siap', 'Tandai Siap'),
        'siap' => ('selesai', 'Selesaikan'),
        _ => null,
      };

  Future<void> _apply(String status) async {
    if (_updating) return;
    setState(() => _updating = true);
    final ok = await ref
        .read(orderHistoryProvider.notifier)
        .updateStatus(widget.order.id, status);
    if (!mounted) return;
    setState(() => _updating = false);
    ref.invalidate(orderDetailProvider(widget.order.id));
    // Status selesai/dibatalkan → meja kembali kosong; segarkan meja.
    ref.invalidate(tablesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Status diperbarui' : 'Gagal memperbarui status')),
    );
  }

  Future<void> _confirmCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text('Pesanan akan dibatalkan dan tidak dapat dipulihkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Tutup'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _apply('dibatalkan');
    }
  }

  @override
  Widget build(BuildContext context) {
    final next = _nextAction;
    if (next == null) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: _updating ? null : () => _apply(next.$1),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(next.$2),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _updating ? null : _confirmCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Batalkan'),
        ),
      ],
    );
  }
}
