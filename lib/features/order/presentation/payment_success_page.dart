import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/printer/printer_service.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';

class PaymentSuccessPage extends ConsumerWidget {
  const PaymentSuccessPage({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));
    final printer = ref.watch(printerProvider);
    final connected = printer.status == PrinterConnectionStatus.connected;
    final cfg = printer.config;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: orderAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Gagal memuat: $e')),
          data: (order) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(48),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.check,
                            size: 56, color: AppColors.success),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Pembayaran Berhasil!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Order ${order.orderNumber ?? '#${order.id}'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.rupiah(order.total),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _OrderSummaryCard(order: order),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: connected
                            ? AppColors.successBg
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              connected ? AppColors.success : AppColors.border,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            switch (cfg.connectionType) {
                              PrinterConnectionType.network =>
                                Icons.lan_outlined,
                              PrinterConnectionType.usb ||
                              PrinterConnectionType.windows =>
                                connected ? Icons.usb : Icons.usb_off_outlined,
                              PrinterConnectionType.bluetooth => connected
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth_disabled,
                            },
                            size: 18,
                            color: connected
                                ? AppColors.success
                                : AppColors.textHint,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              connected
                                  ? 'Printer: ${cfg.name ?? cfg.displayAddress} (Terhubung)'
                                  : 'Printer belum terhubung',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: connected
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                await ref
                                    .read(printerProvider.notifier)
                                    .printReceipt(order);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(const SnackBar(
                                      content: Text('Struk berhasil dicetak.'),
                                      backgroundColor: AppColors.success,
                                    ));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(SnackBar(
                                      content: Text('Gagal cetak: $e'),
                                      backgroundColor: AppColors.danger,
                                    ));
                                }
                              }
                            },
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
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/home/orders/$orderId'),
                        child: const Text('Lihat detail order'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rincian belanja: item, subtotal, biaya tambahan, diskon, total,
/// pembayaran & kembalian — sama dengan isi struk.
class _OrderSummaryCard extends StatelessWidget {
  const _OrderSummaryCard({required this.order});

  final OrderModel order;

  static String _methodLabel(String m) => switch (m) {
        'cash' => 'Tunai',
        'qris' => 'QRIS',
        'transfer' => 'Transfer',
        'card' => 'Kartu',
        _ => m.toUpperCase(),
      };

  String get _costLabel {
    final rate = order.additionalCostRate;
    var rateText = '';
    if (rate != null) {
      final d = rate.toDouble();
      rateText = d == d.roundToDouble() ? ' (${d.toInt()}%)' : ' ($d%)';
    }
    return '${order.additionalCostName ?? 'Biaya Tambahan'}$rateText';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Rincian Belanja',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            for (final it in order.orderItems)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.menuItemName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${it.quantity} x ${Formatters.rupiah(it.price)}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          if (it.notes != null && it.notes!.isNotEmpty)
                            Text(
                              'Catatan: ${it.notes}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.textHint,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.rupiah(it.subtotal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            _Row(label: 'Subtotal', value: Formatters.rupiah(order.subtotal)),
            if (order.additionalCost > 0)
              _Row(
                label: _costLabel,
                value: '+ ${Formatters.rupiah(order.additionalCost)}',
                color: AppColors.info,
              ),
            if (order.discount > 0)
              _Row(
                label: 'Diskon',
                value: '- ${Formatters.rupiah(order.discount)}',
                color: AppColors.danger,
              ),
            if (order.tax > 0)
              _Row(label: 'Pajak', value: '+ ${Formatters.rupiah(order.tax)}'),
            const Divider(height: 20),
            _Row(
              label: 'Total',
              value: Formatters.rupiah(order.total),
              bold: true,
            ),
            for (final p in order.payments) ...[
              const SizedBox(height: 8),
              _Row(
                label: 'Bayar (${_methodLabel(p.method)})',
                value: Formatters.rupiah(p.cashReceived ?? p.amount),
              ),
              if (p.method == 'cash')
                _Row(
                  label: 'Kembalian',
                  value: Formatters.rupiah(
                    p.change ??
                        ((p.cashReceived ?? p.amount) - p.amount)
                            .clamp(0, double.infinity),
                  ),
                  color: AppColors.success,
                  bold: true,
                ),
              if (p.reference != null && p.reference!.isNotEmpty)
                _Row(label: 'Ref', value: p.reference!),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.color,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
