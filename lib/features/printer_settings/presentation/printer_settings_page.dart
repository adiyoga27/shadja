import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/features/printer/printer_service.dart';

class PrinterSettingsPage extends ConsumerStatefulWidget {
  const PrinterSettingsPage({super.key});

  @override
  ConsumerState<PrinterSettingsPage> createState() =>
      _PrinterSettingsPageState();
}

class _PrinterSettingsPageState extends ConsumerState<PrinterSettingsPage> {
  final _storeCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _testing = false;
  bool _init = false;

  @override
  void dispose() {
    _storeCtrl.dispose();
    _addrCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _syncControllers(PrinterConfig cfg) {
    if (_init) return;
    _storeCtrl.text = cfg.storeName;
    _addrCtrl.text = cfg.storeAddress;
    _phoneCtrl.text = cfg.storePhone;
    _init = true;
  }

  Future<void> _save() async {
    final cur = ref.read(printerProvider).config;
    await ref.read(printerProvider.notifier).updateConfig(
          cur.copyWith(
            storeName: _storeCtrl.text.trim(),
            storeAddress: _addrCtrl.text.trim(),
            storePhone: _phoneCtrl.text.trim(),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pengaturan disimpan.'),
            backgroundColor: AppColors.success),
      );
    }
  }

  Future<void> _testPrint() async {
    setState(() => _testing = true);
    try {
      await ref.read(printerProvider.notifier).printTest();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Test print berhasil (cek console).'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerProvider);
    final cfg = printer.config;
    final connected = printer.status == PrinterConnectionStatus.connected;
    _syncControllers(cfg);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Printer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: connected
                            ? AppColors.successBg
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        connected
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_disabled,
                        size: 24,
                        color: connected
                            ? AppColors.success
                            : AppColors.textHint,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cfg.name ?? 'Belum ada printer',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            connected
                                ? 'Terhubung'
                                : (cfg.macAddress != null
                                    ? 'Terputus'
                                    : 'Pilih printer'),
                            style: TextStyle(
                                fontSize: 13,
                                color: connected
                                    ? AppColors.success
                                    : AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.go('/home/printer/scan'),
                    icon: const Icon(Icons.bluetooth_searching, size: 18),
                    label: const Text('Pilih Printer'),
                  ),
                ),
                if (cfg.macAddress != null) ...[
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: () =>
                        ref.read(printerProvider.notifier).forgetPrinter(),
                    icon: const Icon(Icons.delete_outline, size: 18,
                        color: AppColors.danger),
                    tooltip: 'Hapus printer',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // Paper width
            const Text('Lebar Kertas',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PaperOption(
                    label: '58mm',
                    selected: cfg.paperWidth == 58,
                    onTap: () => ref
                        .read(printerProvider.notifier)
                        .updateConfig(cfg.copyWith(paperWidth: 58)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PaperOption(
                    label: '80mm',
                    selected: cfg.paperWidth == 80,
                    onTap: () => ref
                        .read(printerProvider.notifier)
                        .updateConfig(cfg.copyWith(paperWidth: 80)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Auto print toggle
            SwitchListTile.adaptive(
              value: cfg.autoPrint,
              onChanged: (v) => ref
                  .read(printerProvider.notifier)
                  .updateConfig(cfg.copyWith(autoPrint: v)),
              title: const Text('Cetak Otomatis',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              subtitle: const Text('Otomatis cetak struk setelah pembayaran',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              activeTrackColor: AppColors.primary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            const SizedBox(height: 24),

            // Store info
            const Text('Info Toko (untuk Struk)',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _storeCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Toko',
                prefixIcon: Icon(Icons.store_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addrCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Alamat',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'No. Telepon',
                prefixIcon: Icon(Icons.phone_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (!connected || _testing) ? null : _testPrint,
                    icon: _testing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Test Print'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperOption extends StatelessWidget {
  const _PaperOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBg : AppColors.surface,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}