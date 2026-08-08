import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
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
  bool _scanning = true;
  List<BluetoothInfo> _devices = [];
  String? _selectedMac;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _devices = paired;
        _scanning = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
    }
  }

  Future<void> _print(String macAddress, String name) async {
    setState(() {
      _selectedMac = macAddress;
      _printing = true;
    });
    try {
      await ref.read(printerProvider.notifier).setPrinter(macAddress, name);
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

  Future<void> _printWithCurrent() async {
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
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Order: ${widget.order.orderNumber ?? "#${widget.order.id}"}'),
            const SizedBox(height: 12),
            if (connected) ...[
              Row(
                children: [
                  const Icon(Icons.bluetooth_connected,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Terhubung: ${printer.config.name ?? printer.config.macAddress}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ] else if (_scanning) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ] else if (_devices.isNotEmpty) ...[
              const Text('Pilih printer:',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = _devices[index];
                    final isSelected = _selectedMac == d.macAdress;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.bluetooth,
                        size: 18,
                        color:
                            isSelected ? AppColors.primary : AppColors.textHint,
                      ),
                      title: Text(d.name,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(d.macAdress,
                          style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      onTap: _printing ? null : () => _print(d.macAdress, d.name),
                    );
                  },
                ),
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.bluetooth_disabled,
                      size: 18, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Tidak ada printer terpasang.\n'
                      'Pastikan printer sudah dipasangkan (paired) di pengaturan Bluetooth HP/tablet.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _printing ? null : () => Navigator.pop(context),
          child: const Text('Lewati'),
        ),
        if (!connected && !_scanning && _devices.isEmpty)
          TextButton(
            onPressed: _scan,
            child: const Text('Scan Ulang'),
          ),
        if (connected)
          FilledButton.icon(
            onPressed: _printing ? null : _printWithCurrent,
            icon: _printing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.print_outlined, size: 18),
            label: const Text('Cetak'),
          ),
      ],
    );
  }
}
