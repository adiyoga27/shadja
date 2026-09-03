import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:shadja/features/printer/windows_printer.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shadja/core/constants/app_colors.dart';
import 'package:shadja/features/printer/network_printer_scanner.dart';
import 'package:shadja/features/printer/printer_service.dart';

class PrinterScanPage extends ConsumerStatefulWidget {
  const PrinterScanPage({super.key});

  @override
  ConsumerState<PrinterScanPage> createState() => _PrinterScanPageState();
}

class _PrinterScanPageState extends ConsumerState<PrinterScanPage> {
  // Mode / tab
  PrinterConnectionType _mode = PrinterConnectionType.bluetooth;

  // Bluetooth
  bool _scanning = false;
  bool _bluetoothOn = false;
  bool _permissionGranted = false;
  bool _checked = false;
  bool _requestingPermission = false;
  String? _error;
  List<BluetoothInfo> _devices = [];

  // LAN
  final _ipCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '9100');
  bool _lanScanning = false;
  bool _lanTesting = false;
  List<NetworkPrinterDevice> _lanDevices = [];

  // USB
  bool _usbScanning = false;
  List<UsbPrinterDevice> _usbDevices = [];

  // USB Windows (printer terpasang di print spooler)
  List<WindowsPrinterDevice> _windowsPrinters = [];

  @override
  void initState() {
    super.initState();
    _mode = ref.read(printerProvider).config.connectionType;
    _checkStatus();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
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
      if (!perm && Platform.isAndroid) {
        await _requestPermission();
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
    if (!Platform.isAndroid || _requestingPermission) return;
    final sdkInt = await PrintBluetoothThermal.platformVersion;
    final sdk = int.tryParse(sdkInt.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (sdk < 31) return;

    _requestingPermission = true;
    try {
      final status = await Permission.bluetoothConnect.request();
      if (kDebugMode) {
        debugPrint('[PrinterScan] permission request result: $status');
      }
      final perm = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!mounted) return;
      setState(() {
        _permissionGranted = perm;
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
    } finally {
      _requestingPermission = false;
    }
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

  Future<void> _selectBluetooth(BluetoothInfo d) async {
    await ref.read(printerProvider.notifier).setBluetoothPrinter(d.macAdress, d.name);
    if (mounted) context.go('/home/printer');
  }

  // --- LAN ---

  Future<void> _scanLan() async {
    setState(() {
      _lanScanning = true;
      _lanDevices = [];
      _error = null;
    });
    try {
      final results = await NetworkPrinterScanner.scan();
      if (!mounted) return;
      setState(() {
        _lanDevices = results;
        _lanScanning = false;
      });
      if (results.isEmpty) {
        setState(() {
          _error = 'Tidak ditemukan printer LAN.\n\n'
              'Pastikan:\n'
              '1. Printer & HP/tablet terhubung ke Wi-Fi yang sama\n'
              '2. Printer dalam mode LAN (cek lampu indikator)\n'
              '3. Firewall router tidak memblokir port 9100';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lanScanning = false;
        _error = 'Gagal memindai jaringan: $e';
      });
    }
  }

  Future<void> _selectLan(NetworkPrinterDevice d) async {
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    await ref.read(printerProvider.notifier).setNetworkPrinter(
          d.ipAddress,
          port,
          'iWare Thermal (${d.ipAddress})',
        );
    if (mounted) context.go('/home/printer');
  }

  Future<void> _connectManual() async {
    final ip = _ipCtrl.text.trim();
    if (ip.isEmpty) {
      setState(() => _error = 'Masukkan alamat IP printer.');
      return;
    }
    final port = int.tryParse(_portCtrl.text.trim()) ?? 9100;
    setState(() {
      _lanTesting = true;
      _error = null;
    });
    try {
      await ref.read(printerProvider.notifier).setNetworkPrinter(ip, port, 'iWare Thermal ($ip)');
      if (mounted) context.go('/home/printer');
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Gagal terhubung: $e');
      }
    } finally {
      if (mounted) setState(() => _lanTesting = false);
    }
  }

  // --- USB ---

  Future<void> _scanUsb() async {
    if (Platform.isWindows) {
      await _scanWindowsPrinters();
      return;
    }
    setState(() {
      _usbScanning = true;
      _usbDevices = [];
      _error = null;
    });
    try {
      final results = await FlutterUsbPrinter.getUSBDeviceList();
      if (!mounted) return;
      setState(() {
        _usbDevices =
            results.map(UsbPrinterDevice.fromMap).where((d) => d.vendorId > 0).toList();
        _usbScanning = false;
      });
      if (_usbDevices.isEmpty) {
        setState(() {
          _error = 'Tidak ada printer USB terdeteksi.\n\n'
              'Pastikan:\n'
              '1. Printer iWare menyala\n'
              '2. Kabel USB (OTG) terhubung ke HP/tablet\n'
              '3. HP/tablet mendukung USB OTG (host mode)';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usbScanning = false;
        _error = 'Gagal memindai USB: $e';
      });
    }
  }

  Future<void> _selectUsb(UsbPrinterDevice d) async {
    await ref.read(printerProvider.notifier).setUsbPrinter(d);
    if (mounted) context.go('/home/printer');
  }

  Future<void> _scanWindowsPrinters() async {
    setState(() {
      _usbScanning = true;
      _windowsPrinters = [];
      _error = null;
    });
    try {
      final results = await Future(() => WindowsPrinterService.listPrinters());
      if (!mounted) return;
      setState(() {
        _windowsPrinters = results;
        _usbScanning = false;
      });
      if (results.isEmpty) {
        setState(() {
          _error = 'Tidak ada printer terpasang di Windows.\n\n'
              'Pastikan:\n'
              '1. Driver printer iWare sudah diinstal di Windows\n'
              '2. Printer terhubung via kabel USB & menyala\n'
              '3. Printer muncul di Settings > Devices > Printers & Scanners';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usbScanning = false;
        _error = 'Gagal memindai printer Windows: $e';
      });
    }
  }

  Future<void> _selectWindows(WindowsPrinterDevice d) async {
    await ref.read(printerProvider.notifier).setWindowsPrinter(d.name);
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
      body: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            TabBar(
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              onTap: (i) => setState(() {
                _mode = switch (i) {
                  0 => PrinterConnectionType.bluetooth,
                  1 => PrinterConnectionType.network,
                  _ => PrinterConnectionType.usb,
                };
                _error = null;
              }),
              tabs: const [
                Tab(text: 'Bluetooth', icon: Icon(Icons.bluetooth, size: 20)),
                Tab(text: 'LAN (Wi-Fi)', icon: Icon(Icons.lan_outlined, size: 20)),
                Tab(text: 'USB', icon: Icon(Icons.usb, size: 20)),
              ],
            ),
            Expanded(
              child: switch (_mode) {
                PrinterConnectionType.bluetooth => _buildBluetoothTab(),
                PrinterConnectionType.network => _buildLanTab(),
                PrinterConnectionType.usb ||
                PrinterConnectionType.windows =>
                  _buildUsbTab(),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          _InfoBanner(error: _error, message: _error != null
              ? null
              : 'Pastikan printer iWare sudah menyala dan dipasangkan (paired) di pengaturan Bluetooth HP/tablet sebelum scan.'),
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
                      return _DeviceTile(
                        icon: Icons.bluetooth,
                        title: d.name,
                        subtitle: d.macAdress,
                        onTap: () => _selectBluetooth(d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _ipCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Alamat IP printer',
              hintText: 'contoh: 192.168.1.100',
              prefixIcon: Icon(Icons.lan_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _portCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Port',
              hintText: '9100',
              prefixIcon: Icon(Icons.numbers, size: 18),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _lanTesting ? null : _connectManual,
            icon: _lanTesting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.link, size: 18),
            label: Text(_lanTesting ? 'Menghubungkan…' : 'Hubungkan'),
          ),
          const SizedBox(height: 20),
          _InfoBanner(
            error: _error,
            message: _error != null
                ? null
                : 'Tidak tahu IP printer? Tekan tombol "Cari IP Printer" di bawah untuk memindai otomatis seluruh jaringan.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _lanScanning ? null : _scanLan,
            icon: _lanScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_find, size: 18),
            label: Text(_lanScanning ? 'Memindai jaringan…' : 'Cari IP Printer'),
          ),
          const SizedBox(height: 8),
          Text(
            'Memindai seluruh subnet (dapat memakan waktu ±1 menit).',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _lanDevices.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    itemCount: _lanDevices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final d = _lanDevices[index];
                      return _DeviceTile(
                        icon: Icons.print_outlined,
                        title: 'iWare Thermal (${d.ipAddress})',
                        subtitle: 'Port 9100 — ketuk untuk memilih',
                        onTap: () => _selectLan(d),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsbTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoBanner(
            error: _error,
            message: _error != null
                ? null
                : Platform.isWindows
                    ? 'Pilih printer yang sudah terpasang di Windows (driver terinstal, printer dicolok via USB), lalu tekan "Scan USB".'
                    : 'Colokkan printer iWare ke HP/tablet via kabel USB (OTG), lalu tekan "Scan USB".',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _usbScanning ? null : _scanUsb,
            icon: _usbScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.usb, size: 18),
            label: Text(_usbScanning ? 'Memindai…' : 'Scan USB'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Platform.isWindows
                ? _buildWindowsUsbList()
                : _buildAndroidUsbList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidUsbList() {
    if (_usbDevices.isNotEmpty) {
      return ListView.separated(
        itemCount: _usbDevices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final d = _usbDevices[index];
          return _DeviceTile(
            icon: Icons.print_outlined,
            title: d.displayName,
            subtitle:
                'VID:${d.vendorId.toRadixString(16)} PID:${d.productId.toRadixString(16)} — ketuk untuk memilih',
            onTap: () => _selectUsb(d),
          );
        },
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        if (!_usbScanning)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.usb_off_outlined,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada printer USB.',
                    style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Cara menggunakan printer USB:\n'
                    '1. Nyalakan printer iWare\n'
                    '2. Hubungkan kabel USB (OTG) ke HP/tablet\n'
                    '3. Tekan "Scan USB"\n'
                    '4. Izinkan akses USB bila diminta\n'
                    '5. Pilih printer',
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
    );
  }

  Widget _buildWindowsUsbList() {
    if (_windowsPrinters.isNotEmpty) {
      return ListView.separated(
        itemCount: _windowsPrinters.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final d = _windowsPrinters[index];
          return _DeviceTile(
            icon: Icons.print_outlined,
            title: d.name,
            subtitle: [
              if (d.driver != null && d.driver!.isNotEmpty) d.driver!,
              if (d.port != null && d.port!.isNotEmpty) d.port!,
            ].join(' • '),
            onTap: () => _selectWindows(d),
          );
        },
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [
        if (!_usbScanning)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.usb_off_outlined,
                      size: 56, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text(
                    'Belum ada printer terpasang.',
                    style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Cara menggunakan printer USB di Windows:\n'
                    '1. Colokkan printer ke laptop via kabel USB\n'
                    '2. Instal driver printer (otomatis atau dari CD/situs resmi)\n'
                    '3. Pastikan muncul di Settings > Printers & Scanners\n'
                    '4. Tekan "Scan USB" lalu pilih printer',
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
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({this.error, this.message});
  final String? error;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final showError = error != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: showError ? AppColors.warningBg : AppColors.infoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            showError ? Icons.warning_amber : Icons.info_outline,
            size: 20,
            color: showError ? AppColors.warning : AppColors.info,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error ?? message ?? '',
              style: TextStyle(
                fontSize: 13,
                color: showError ? AppColors.warning : AppColors.info,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                child: Icon(icon, size: 22, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle_outline, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
