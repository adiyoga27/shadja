import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/core/utils/formatters.dart';
import 'package:shadja/features/printer/presentation/print_dialog.dart';
import 'package:shadja/features/order/presentation/order_provider.dart';

class PaymentSuccessPage extends ConsumerWidget {
  const PaymentSuccessPage({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(orderId));

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
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await PrintDialog.show(context, order: order);
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