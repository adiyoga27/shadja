import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/features/printer/printer_service.dart';

class PrinterScanPage extends ConsumerStatefulWidget {
  const PrinterScanPage({super.key});

  @override
  ConsumerState<PrinterScanPage> createState() => _PrinterScanPageState();
}

class _PrinterScanPageState extends ConsumerState<PrinterScanPage> {
  bool _scanning = false;
  bool _bluetoothOn = false;
  bool _permissionGranted = false;
  bool _checked = false;
  String? _error;
  List<BluetoothInfo> _devices = [];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final bt = await PrintBluetoothThermal.bluetoothEnabled;
      final perm = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (kDebugMode) {
        debugPrint('[PrinterScan] bluetoothEnabled=$bt, permissionGranted=$perm');
      }
      if (!mounted) return;
      setState(() {
        _bluetoothOn = bt;
        _permissionGranted = perm;
        _checked = true;
      });
      if (!perm) {
        setState(() {
          _error = 'Izin "Perangkat sekitar" (Nearby devices) belum diberikan.\n\n'
              'Cara mengaktifkan:\n'
              '1. Buka Pengaturan HP\n'
              '2. Pilih Aplikasi > Shadja\n'
              '3. Pilih Izin > Perangkat sekitar\n'
              '4. Izinkan\n'
              '5. Kembali & tekan Scan lagi';
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PrinterScan] _checkStatus error: $e');
      }
      if (!mounted) return;
      setState(() {
        _checked = true;
        _error = 'Gagal cek status Bluetooth: $e';
      });
    }
  }

  Future<void> _requestPermission() async {
    if (!Platform.isAndroid) return;
    final sdkInt = await PrintBluetoothThermal.platformVersion;
    final sdk = int.tryParse(sdkInt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (sdk < 31) return;

    final status = await Permission.bluetoothConnect.request();
    if (kDebugMode) {
      debugPrint('[PrinterScan] permission request result: $status');
    }
    // Refresh status after permission request
    await _checkStatus();
  }

  Future<void> _onScanPressed() async {
    if (!_checked) await _checkStatus();

    if (!_permissionGranted && Platform.isAndroid) {
      await _requestPermission();
      if (!_permissionGranted && mounted) {
        setState(() {
          _error = 'Izin diperlukan. Silakan "Izinkan" saat dialog muncul, lalu tekan Scan lagi.';
        });
        return;
      }
    }

    _startScan();
  }

  Future<void> _startScan() async {

    setState(() {
      _scanning = true;
      _devices = [];
      _error = null;
    });

    if (!_bluetoothOn) {
      setState(() {
        _scanning = false;
        _error = 'Bluetooth mati. Aktifkan Bluetooth di pengaturan HP, lalu coba lagi.';
      });
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('[PrinterScan] calling pairedBluetooths...');
      }
      final paired = await PrintBluetoothThermal.pairedBluetooths
          .timeout(const Duration(seconds: 10));
      if (kDebugMode) {
        debugPrint('[PrinterScan] pairedBluetooths returned ${paired.length} devices');
        for (final d in paired) {
          debugPrint('[PrinterScan]   - ${d.name} (${d.macAdress})');
        }
      }
      if (!mounted) return;
      setState(() {
        _devices = paired;
        _scanning = false;
      });

      if (_devices.isEmpty) {
        setState(() {
          _error = 'Tidak ada printer yang terpasang.\n\n'
              'Pastikan:\n'
              '1. Printer iWare menyala (lampu indikator ON)\n'
              '2. Sudah dipasangkan di Pengaturan > Bluetooth\n'
              '3. Tidak sedang terhubung ke device lain';
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Scan timeout. Pastikan izin "Perangkat sekitar" sudah diberikan.\n'
            'Cek: Pengaturan HP > Aplikasi > Shadja > Izin';
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[PrinterScan] pairedBluetooths error: $e');
      }
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Gagal memindai: $e';
      });
    }
  }

  Future<void> _select(BluetoothInfo d) async {
    await ref.read(printerProvider.notifier).setPrinter(d.macAdress, d.name);
    if (mounted) context.go('/home/printer');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Printer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bluetooth status
            if (_checked) ...[
              Row(
                children: [
                  Icon(
                    _bluetoothOn ? Icons.bluetooth : Icons.bluetooth_disabled,
                    color: _bluetoothOn ? AppColors.success : AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _bluetoothOn ? 'Bluetooth aktif' : 'Bluetooth mati',
                    style: TextStyle(
                      fontSize: 13,
                      color: _bluetoothOn ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _permissionGranted ? 'Izin OK' : 'Perlu izin',
                    style: TextStyle(
                      fontSize: 13,
                      color: _permissionGranted ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _error != null ? AppColors.warningBg : AppColors.infoBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _error != null ? Icons.warning_amber : Icons.info_outline,
                    size: 20,
                    color: _error != null ? AppColors.warning : AppColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error ??
                          'Pastikan printer iWare sudah menyala dan dipasangkan (paired) di pengaturan Bluetooth HP/tablet sebelum scan.',
                      style: TextStyle(
                        fontSize: 13,
                        color: _error != null ? AppColors.warning : AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _scanning ? null : _onScanPressed,
              icon: _scanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_scanning ? 'Memindai…' : 'Scan Printer'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _devices.isEmpty
                  ? ListView(
                      shrinkWrap: true,
                      children: [
                        if (!_scanning && _checked)
                          const Padding(
                            padding: EdgeInsets.only(top: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.bluetooth_searching,
                                      size: 56, color: AppColors.textHint),
                                  SizedBox(height: 12),
                                  Text(
                                    'Belum ada printer ditemukan.',
                                    style: TextStyle(
                                        fontSize: 15,
                                        color: AppColors.textPrimary),
                                  ),
                                  SizedBox(height: 24),
                                  Text(
                                    'Cara memasangkan printer:\n'
                                    '1. Nyalakan printer iWare\n'
                                    '2. Buka Pengaturan HP/tablet\n'
                                    '3. Pilih Bluetooth\n'
                                    '4. Cari & pasangkan printer\n'
                                    '5. Kembali & tekan Scan Printer',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        height: 1.8),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _devices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final d = _devices[index];
                        return Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _select(d),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.print_outlined,
                                        size: 22, color: AppColors.primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          d.name,
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          d.macAdress,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.check_circle_outline,
                                      color: AppColors.primary),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
