import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/printer/printer_service.dart';

class PrintDialog extends ConsumerStatefulWidget {
  const PrintDialog({super.key, required this.order});

  final OrderModel order;

  static Future<void> show(BuildContext context, {required OrderModel order}) {
    return showDialog<void>(
      context: context,
      builder: (_) => PrintDialog(order: order),
    );
  }

  @override
  ConsumerState<PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends ConsumerState<PrintDialog> {
  bool _printing = false;

  Future<void> _print() async {
    setState(() => _printing = true);
    try {
      await ref.read(printerProvider.notifier).printReceipt(widget.order);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Struk berhasil dicetak.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal cetak: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerProvider);
    final connected = printer.status == PrinterConnectionStatus.connected;

    return AlertDialog(
      icon: const Icon(Icons.print_outlined, color: AppColors.primary),
      title: const Text('Cetak Struk'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Order: ${widget.order.orderNumber ?? "#${widget.order.id}"}'),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                size: 18,
                color: connected ? AppColors.success : AppColors.textHint,
              ),
              const SizedBox(width: 6),
              Text(
                connected
                    ? 'Printer: ${printer.config.name ?? "Terhubung"}'
                    : 'Printer tidak terhubung',
                style: TextStyle(
                    fontSize: 13,
                    color: connected
                        ? AppColors.success
                        : AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Lewati'),
        ),
        if (!connected)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Sambungkan Printer'),
          ),
        FilledButton.icon(
          onPressed: (connected && !_printing) ? _print : null,
          icon: _printing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.print_outlined, size: 18),
          label: const Text('Cetak'),
        ),
      ],
    );
  }
}