import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_usb_printer/flutter_usb_printer.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/printer/receipt_formatter.dart';
import 'package:shadja/features/store_profile/data/store_profile_model.dart';
import 'package:shadja/features/store_profile/data/store_profile_repository.dart';
import 'package:shadja/core/storage/token_storage.dart';

enum PrinterConnectionStatus { disconnected, connecting, connected }

enum PrinterConnectionType { bluetooth, network, usb }

extension PrinterConnectionTypeLabel on PrinterConnectionType {
  String get label => switch (this) {
        PrinterConnectionType.bluetooth => 'Bluetooth',
        PrinterConnectionType.network => 'LAN (Wi-Fi)',
        PrinterConnectionType.usb => 'USB',
      };
}

class UsbPrinterDevice {
  const UsbPrinterDevice({
    required this.vendorId,
    required this.productId,
    this.deviceName,
    this.manufacturer,
    this.productName,
  });

  final int vendorId;
  final int productId;
  final String? deviceName;
  final String? manufacturer;
  final String? productName;

  factory UsbPrinterDevice.fromMap(Map<String, dynamic> map) => UsbPrinterDevice(
        vendorId: int.tryParse('${map['vendorId']}') ?? 0,
        productId: int.tryParse('${map['productId']}') ?? 0,
        deviceName: map['deviceName'] as String?,
        manufacturer: map['manufacturer'] as String?,
        productName: map['productName'] as String?,
      );

  String get displayName {
    final name = '${manufacturer ?? ''} ${productName ?? ''}'.trim();
    return name.isNotEmpty ? name : (deviceName ?? 'USB Printer');
  }
}

class PrinterConfig {
  const PrinterConfig({
    this.connectionType = PrinterConnectionType.bluetooth,
    this.macAddress,
    this.ipAddress,
    this.port = 9100,
    this.usbVendorId,
    this.usbProductId,
    this.name,
    this.paperWidth = 80,
    this.autoPrint = false,
    this.printCopies = 3,
    this.storeName = 'Shadja Karangasem',
    this.storeAddress = 'Jln Tunjung Bang, Bungaya Bebandem Karangasem',
    this.storePhone = '082342233213',
  });

  final PrinterConnectionType connectionType;
  final String? macAddress;
  final String? ipAddress;
  final int port;
  final int? usbVendorId;
  final int? usbProductId;
  final String? name;
  final int paperWidth;
  final bool autoPrint;
  final int printCopies;
  final String storeName;
  final String storeAddress;
  final String storePhone;

  bool get isConfigured => switch (connectionType) {
        PrinterConnectionType.bluetooth =>
          macAddress != null && macAddress!.isNotEmpty,
        PrinterConnectionType.network =>
          ipAddress != null && ipAddress!.isNotEmpty,
        PrinterConnectionType.usb =>
          usbVendorId != null && usbProductId != null,
      };

  String get displayAddress => switch (connectionType) {
        PrinterConnectionType.bluetooth => macAddress ?? '',
        PrinterConnectionType.network => '$ipAddress:$port',
        PrinterConnectionType.usb => '$usbVendorId:$usbProductId',
      };

  PrinterConfig copyWith({
    PrinterConnectionType? connectionType,
    String? macAddress,
    String? ipAddress,
    int? port,
    int? usbVendorId,
    int? usbProductId,
    String? name,
    int? paperWidth,
    bool? autoPrint,
    int? printCopies,
    String? storeName,
    String? storeAddress,
    String? storePhone,
  }) =>
      PrinterConfig(
        connectionType: connectionType ?? this.connectionType,
        macAddress: macAddress ?? this.macAddress,
        ipAddress: ipAddress ?? this.ipAddress,
        port: port ?? this.port,
        usbVendorId: usbVendorId ?? this.usbVendorId,
        usbProductId: usbProductId ?? this.usbProductId,
        name: name ?? this.name,
        paperWidth: paperWidth ?? this.paperWidth,
        autoPrint: autoPrint ?? this.autoPrint,
        printCopies: printCopies ?? this.printCopies,
        storeName: storeName ?? this.storeName,
        storeAddress: storeAddress ?? this.storeAddress,
        storePhone: storePhone ?? this.storePhone,
      );
}

class PrinterState {
  const PrinterState({
    this.config = const PrinterConfig(),
    this.status = PrinterConnectionStatus.disconnected,
    this.error,
  });

  final PrinterConfig config;
  final PrinterConnectionStatus status;
  final String? error;

  PrinterState copyWith({
    PrinterConfig? config,
    PrinterConnectionStatus? status,
    String? error,
  }) =>
      PrinterState(
        config: config ?? this.config,
        status: status ?? this.status,
        error: error,
      );
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  PrinterNotifier(this._storeProfileRepo) : super(const PrinterState()) {
    _loadConfig();
  }

  final StoreProfileRepository _storeProfileRepo;

  static const _kType = 'printer_type';
  static const _kMac = 'printer_mac';
  static const _kIp = 'printer_ip';
  static const _kPort = 'printer_port';
  static const _kVid = 'printer_usb_vid';
  static const _kPid = 'printer_usb_pid';
  static const _kName = 'printer_name';
  static const _kPaper = 'printer_paper';
  static const _kAuto = 'printer_auto';
  static const _kCopies = 'printer_copies';
  static const _kStore = 'printer_store';
  static const _kAddr = 'printer_addr';
  static const _kPhone = 'printer_phone';

  Socket? _socket;
  final FlutterUsbPrinter _usbPrinter = FlutterUsbPrinter();

  Future<void> _loadConfig() async {
    final typeStr = await TokenStorage.read(_kType);
    final type = switch (typeStr) {
      'network' => PrinterConnectionType.network,
      'usb' => PrinterConnectionType.usb,
      _ => PrinterConnectionType.bluetooth,
    };
    final mac = await TokenStorage.read(_kMac);
    final ip = await TokenStorage.read(_kIp);
    final port = int.tryParse(await TokenStorage.read(_kPort) ?? '9100') ?? 9100;
    final vid = int.tryParse(await TokenStorage.read(_kVid) ?? '');
    final pid = int.tryParse(await TokenStorage.read(_kPid) ?? '');
    final name = await TokenStorage.read(_kName);
    final paper = int.tryParse(await TokenStorage.read(_kPaper) ?? '80') ?? 80;
    final auto = (await TokenStorage.read(_kAuto)) == 'true';
    final copies =
        int.tryParse(await TokenStorage.read(_kCopies) ?? '3') ?? 3;
    var store = await TokenStorage.read(_kStore) ?? 'Shadja Karangasem';
    var addr = await TokenStorage.read(_kAddr) ?? 'Jln Tunjung Bang, Bungaya Bebandem Karangasem';
    var phone = await TokenStorage.read(_kPhone) ?? '082342233213';

    // Info toko diambil dari API (store-profiles); localStorage hanya fallback.
    final profile = await _fetchStoreProfile();
    if (profile != null) {
      store = profile.storeName;
      addr = profile.storeAddress;
      phone = profile.storePhone;
      await TokenStorage.write(_kStore, store);
      await TokenStorage.write(_kAddr, addr);
      await TokenStorage.write(_kPhone, phone);
    }

    final config = PrinterConfig(
      connectionType: type,
      macAddress: mac,
      ipAddress: ip,
      port: port,
      usbVendorId: vid,
      usbProductId: pid,
      name: name,
      paperWidth: paper,
      autoPrint: auto,
      printCopies: copies.clamp(1, 9),
      storeName: store,
      storeAddress: addr,
      storePhone: phone,
    );

    state = PrinterState(
      config: config,
      status: PrinterConnectionStatus.disconnected,
    );

    if (config.isConfigured) {
      if (kDebugMode) {
        debugPrint('[Printer] _loadConfig: auto-connecting to $name (${config.displayAddress})');
      }
      await Future.delayed(const Duration(milliseconds: 800));
      await connect();
    }
  }

  Future<StoreProfileModel?> _fetchStoreProfile() async {
    try {
      return await _storeProfileRepo.fetch();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Printer] fetch store profile gagal: $e');
      }
      return null;
    }
  }

  Future<void> setBluetoothPrinter(String macAddress, String name) async {
    await _saveConnection(
      type: PrinterConnectionType.bluetooth,
      macAddress: macAddress,
      ipAddress: null,
      name: name,
    );
    await connect();
  }

  Future<void> setNetworkPrinter(String ipAddress, int port, String name) async {
    await _saveConnection(
      type: PrinterConnectionType.network,
      macAddress: null,
      ipAddress: ipAddress,
      port: port,
      name: name,
    );
    await connect();
  }

  Future<void> setUsbPrinter(UsbPrinterDevice device) async {
    await _saveConnection(
      type: PrinterConnectionType.usb,
      macAddress: null,
      ipAddress: null,
      usbVendorId: device.vendorId,
      usbProductId: device.productId,
      name: device.displayName,
    );
    await connect();
  }

  Future<void> _saveConnection({
    required PrinterConnectionType type,
    String? macAddress,
    String? ipAddress,
    int? port,
    int? usbVendorId,
    int? usbProductId,
    String? name,
  }) async {
    await TokenStorage.write(_kType, type.name);
    await TokenStorage.write(_kName, name ?? '');
    switch (type) {
      case PrinterConnectionType.network:
        await TokenStorage.write(_kIp, ipAddress ?? '');
        await TokenStorage.write(_kPort, (port ?? 9100).toString());
        await TokenStorage.delete(_kMac);
        await TokenStorage.delete(_kVid);
        await TokenStorage.delete(_kPid);
      case PrinterConnectionType.bluetooth:
        await TokenStorage.write(_kMac, macAddress ?? '');
        await TokenStorage.delete(_kIp);
        await TokenStorage.delete(_kVid);
        await TokenStorage.delete(_kPid);
      case PrinterConnectionType.usb:
        await TokenStorage.write(_kVid, (usbVendorId ?? 0).toString());
        await TokenStorage.write(_kPid, (usbProductId ?? 0).toString());
        await TokenStorage.delete(_kMac);
        await TokenStorage.delete(_kIp);
    }
    state = state.copyWith(
      config: state.config.copyWith(
        connectionType: type,
        macAddress: type == PrinterConnectionType.bluetooth ? macAddress : null,
        ipAddress: type == PrinterConnectionType.network ? ipAddress : null,
        port: type == PrinterConnectionType.network ? port : state.config.port,
        usbVendorId: type == PrinterConnectionType.usb ? usbVendorId : null,
        usbProductId: type == PrinterConnectionType.usb ? usbProductId : null,
        name: name,
      ),
      status: PrinterConnectionStatus.connecting,
      error: null,
    );
  }

  Future<void> connect() async {
    final cfg = state.config;
    if (!cfg.isConfigured) return;

    state = state.copyWith(
        status: PrinterConnectionStatus.connecting, error: null);
    try {
      switch (cfg.connectionType) {
        case PrinterConnectionType.bluetooth:
          await _connectBluetooth(cfg.macAddress!);
        case PrinterConnectionType.network:
          await _connectNetwork(cfg.ipAddress!, cfg.port);
        case PrinterConnectionType.usb:
          await _connectUsb(cfg.usbVendorId!, cfg.usbProductId!);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Printer] connect error: $e');
      }
      state = state.copyWith(
        status: PrinterConnectionStatus.disconnected,
        error: 'Gagal menyambung: $e',
      );
    }
  }

  Future<void> _connectBluetooth(String macAddress) async {
    final btOn = await PrintBluetoothThermal.bluetoothEnabled;
    if (!btOn) {
      state = state.copyWith(
        status: PrinterConnectionStatus.disconnected,
        error: 'Bluetooth mati.',
      );
      return;
    }

    final alreadyConnected = await PrintBluetoothThermal.connectionStatus;
    if (alreadyConnected) {
      if (kDebugMode) {
        debugPrint('[Printer] already connected');
      }
      state = state.copyWith(status: PrinterConnectionStatus.connected);
      return;
    }

    await PrintBluetoothThermal.pairedBluetooths;

    final connected =
        await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
    if (kDebugMode) {
      debugPrint('[Printer] connect result: $connected');
    }
    if (connected) {
      state = state.copyWith(status: PrinterConnectionStatus.connected);
    } else {
      state = state.copyWith(
        status: PrinterConnectionStatus.disconnected,
        error: 'Gagal menyambung ke printer.',
      );
    }
  }

  Future<void> _connectNetwork(String ipAddress, int port) async {
    await _closeSocket();
    final socket = await Socket.connect(ipAddress, port,
        timeout: const Duration(seconds: 5));
    _socket = socket;
    state = state.copyWith(status: PrinterConnectionStatus.connected);
  }

  Future<void> _connectUsb(int vendorId, int productId) async {
    if (!Platform.isAndroid) {
      throw PrinterException('USB hanya didukung di perangkat Android.');
    }
    final isConnected = await _usbPrinter.isConnected();
    if (isConnected) {
      state = state.copyWith(status: PrinterConnectionStatus.connected);
      return;
    }
    final connected = await _usbPrinter.connect(vendorId, productId);
    if (kDebugMode) {
      debugPrint('[Printer] usb connect result: $connected');
    }
    if (connected == true) {
      state = state.copyWith(status: PrinterConnectionStatus.connected);
    } else {
      state = state.copyWith(
        status: PrinterConnectionStatus.disconnected,
        error: 'Gagal menyambung ke printer USB. '
            'Pastikan printer terhubung via kabel USB (OTG) dan izin akses USB diberikan.',
      );
    }
  }

  Future<void> disconnect() async {
    switch (state.config.connectionType) {
      case PrinterConnectionType.bluetooth:
        await PrintBluetoothThermal.disconnect;
      case PrinterConnectionType.network:
        await _closeSocket();
      case PrinterConnectionType.usb:
        await _usbPrinter.close();
    }
    state = state.copyWith(status: PrinterConnectionStatus.disconnected);
  }

  Future<void> _closeSocket() async {
    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  Future<void> forgetPrinter() async {
    await disconnect();
    await TokenStorage.delete(_kType);
    await TokenStorage.delete(_kMac);
    await TokenStorage.delete(_kIp);
    await TokenStorage.delete(_kVid);
    await TokenStorage.delete(_kPid);
    await TokenStorage.delete(_kName);
    state = state.copyWith(
      config: PrinterConfig(
        paperWidth: state.config.paperWidth,
        autoPrint: state.config.autoPrint,
        printCopies: state.config.printCopies,
        storeName: state.config.storeName,
        storeAddress: state.config.storeAddress,
        storePhone: state.config.storePhone,
      ),
      status: PrinterConnectionStatus.disconnected,
    );
  }

  Future<void> updateConfig(PrinterConfig config) async {
    await TokenStorage.write(_kPaper, config.paperWidth.toString());
    await TokenStorage.write(_kAuto, config.autoPrint ? 'true' : 'false');
    await TokenStorage.write(_kCopies, config.printCopies.toString());
    state = state.copyWith(config: config);
  }

  /// Simpan info toko via API (store-profiles, PUT upsert).
  /// Mengembalikan pesan error bila gagal sinkron, atau null bila berhasil.
  Future<String?> updateStoreInfo({
    required String storeName,
    required String storeAddress,
    required String storePhone,
  }) async {
    if (storeName.trim().isEmpty) return 'Nama toko wajib diisi.';

    try {
      final profile = await _storeProfileRepo.save(
        storeName: storeName.trim(),
        storeAddress: storeAddress.trim(),
        storePhone: storePhone.trim(),
      );
      await Future.wait([
        TokenStorage.write(_kStore, profile.storeName),
        TokenStorage.write(_kAddr, profile.storeAddress),
        TokenStorage.write(_kPhone, profile.storePhone),
      ]);
      state = state.copyWith(
        config: state.config.copyWith(
          storeName: profile.storeName,
          storeAddress: profile.storeAddress,
          storePhone: profile.storePhone,
        ),
      );
      return null;
    } catch (e) {
      // Tetap simpan lokal agar struk bisa dicetak (offline fallback).
      await Future.wait([
        TokenStorage.write(_kStore, storeName.trim()),
        TokenStorage.write(_kAddr, storeAddress.trim()),
        TokenStorage.write(_kPhone, storePhone.trim()),
      ]);
      state = state.copyWith(
        config: state.config.copyWith(
          storeName: storeName.trim(),
          storeAddress: storeAddress.trim(),
          storePhone: storePhone.trim(),
        ),
      );
      if (kDebugMode) {
        debugPrint('[Printer] save store profile gagal: $e');
      }
      return 'Gagal sinkron info toko ke server. Data disimpan lokal.';
    }
  }

  Future<void> printReceipt(OrderModel order) async {
    // Info toko diambil dari API (store-profiles) agar struk selalu terbaru.
    // Lokal (state.config) hanya fallback bila API gagal / belum ada profil.
    var storeName = state.config.storeName;
    var storeAddress = state.config.storeAddress;
    var storePhone = state.config.storePhone;
    final profile = await _fetchStoreProfile();
    if (profile != null) {
      storeName = profile.storeName;
      storeAddress = profile.storeAddress;
      storePhone = profile.storePhone;
    }

    final copies = state.config.printCopies.clamp(1, 9);
    final bytes = await ReceiptFormatter.formatBytes(
      order: order,
      storeName: storeName,
      storeAddress: storeAddress,
      storePhone: storePhone,
      paperWidth: state.config.paperWidth,
    );
    for (var i = 0; i < copies; i++) {
      await _writeBytes(bytes);
      if (i < copies - 1) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
  }

  Future<void> printTest() async {
    final bytes = await ReceiptFormatter.testBytes(
      storeName: state.config.storeName,
      paperWidth: state.config.paperWidth,
    );
    await _writeBytes(bytes);
  }

  Future<void> _writeBytes(List<int> bytes) async {
    switch (state.config.connectionType) {
      case PrinterConnectionType.bluetooth:
        final isConnected = await PrintBluetoothThermal.connectionStatus;
        if (!isConnected) {
          throw PrinterException('Printer belum terhubung.');
        }
        final result = await PrintBluetoothThermal.writeBytes(bytes);
        if (!result) {
          throw PrinterException('Gagal mengirim data ke printer.');
        }
      case PrinterConnectionType.network:
        final socket = _socket;
        if (socket == null) {
          throw PrinterException('Printer belum terhubung.');
        }
        try {
          socket.add(bytes);
          await socket.flush();
        } catch (e) {
          throw PrinterException('Gagal mengirim data ke printer: $e');
        }
      case PrinterConnectionType.usb:
        final vid = state.config.usbVendorId;
        final pid = state.config.usbProductId;
        if (vid == null || pid == null) {
          throw PrinterException('Printer belum terhubung.');
        }
        final result = await _usbPrinter.sendData(
          vid,
          pid,
          Uint8List.fromList(bytes),
        );
        if (result != true) {
          throw PrinterException(
              'Gagal mengirim data ke printer USB. Pastikan kabel USB terhubung.');
        }
    }
  }
}

class PrinterException implements Exception {
  PrinterException(this.message);
  final String message;
  @override
  String toString() => message;
}

final printerProvider =
    StateNotifierProvider<PrinterNotifier, PrinterState>(
  (ref) => PrinterNotifier(ref.read(storeProfileRepositoryProvider)),
);
