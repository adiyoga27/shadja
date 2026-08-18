import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/utils/formatters.dart';
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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                  const SizedBox(height: 24),
                  const Text(
                    'Pembayaran Berhasil!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order ${order.orderNumber ?? '#${order.id}'}',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.rupiah(order.total),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cfg.connectionType == PrinterConnectionType.network
                              ? (connected
                                  ? Icons.lan_outlined
                                  : Icons.lan_outlined)
                              : (connected
                                  ? Icons.bluetooth_connected
                                  : Icons.bluetooth_disabled),
                          size: 18,
                          color:
                              connected ? AppColors.success : AppColors.textHint,
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
                  const SizedBox(height: 24),
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
                  TextButton(
                    onPressed: () =>
                        context.go('/home/orders/$orderId'),
                    child: const Text('Lihat detail order'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}