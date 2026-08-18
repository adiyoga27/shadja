import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/printer/receipt_formatter.dart';
import 'package:shadja/core/storage/token_storage.dart';

enum PrinterConnectionStatus { disconnected, connecting, connected }

enum PrinterConnectionType { bluetooth, network }

extension PrinterConnectionTypeLabel on PrinterConnectionType {
  String get label => switch (this) {
        PrinterConnectionType.bluetooth => 'Bluetooth',
        PrinterConnectionType.network => 'LAN (Wi-Fi)',
      };
}

class PrinterConfig {
  const PrinterConfig({
    this.connectionType = PrinterConnectionType.bluetooth,
    this.macAddress,
    this.ipAddress,
    this.port = 9100,
    this.name,
    this.paperWidth = 80,
    this.autoPrint = false,
    this.printCopies = 1,
    this.storeName = 'Shadja Restaurant',
    this.storeAddress = 'Jl. Contoh No. 123',
    this.storePhone = '08123456789',
  });

  final PrinterConnectionType connectionType;
  final String? macAddress;
  final String? ipAddress;
  final int port;
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
      };

  String get displayAddress => switch (connectionType) {
        PrinterConnectionType.bluetooth => macAddress ?? '',
        PrinterConnectionType.network => '$ipAddress:$port',
      };

  PrinterConfig copyWith({
    PrinterConnectionType? connectionType,
    String? macAddress,
    String? ipAddress,
    int? port,
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
  PrinterNotifier() : super(const PrinterState()) {
    _loadConfig();
  }

  static const _kType = 'printer_type';
  static const _kMac = 'printer_mac';
  static const _kIp = 'printer_ip';
  static const _kPort = 'printer_port';
  static const _kName = 'printer_name';
  static const _kPaper = 'printer_paper';
  static const _kAuto = 'printer_auto';
  static const _kCopies = 'printer_copies';
  static const _kStore = 'printer_store';
  static const _kAddr = 'printer_addr';
  static const _kPhone = 'printer_phone';

  Socket? _socket;

  Future<void> _loadConfig() async {
    final typeStr = await TokenStorage.read(_kType);
    final type = typeStr == 'network'
        ? PrinterConnectionType.network
        : PrinterConnectionType.bluetooth;
    final mac = await TokenStorage.read(_kMac);
    final ip = await TokenStorage.read(_kIp);
    final port = int.tryParse(await TokenStorage.read(_kPort) ?? '9100') ?? 9100;
    final name = await TokenStorage.read(_kName);
    final paper = int.tryParse(await TokenStorage.read(_kPaper) ?? '80') ?? 80;
    final auto = (await TokenStorage.read(_kAuto)) == 'true';
    final copies =
        int.tryParse(await TokenStorage.read(_kCopies) ?? '1') ?? 1;
    final store = await TokenStorage.read(_kStore) ?? 'Shadja Restaurant';
    final addr = await TokenStorage.read(_kAddr) ?? 'Jl. Contoh No. 123';
    final phone = await TokenStorage.read(_kPhone) ?? '08123456789';

    final config = PrinterConfig(
      connectionType: type,
      macAddress: mac,
      ipAddress: ip,
      port: port,
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

  Future<void> _saveConnection({
    required PrinterConnectionType type,
    String? macAddress,
    String? ipAddress,
    int? port,
    String? name,
  }) async {
    await TokenStorage.write(_kType, type.name);
    await TokenStorage.write(_kName, name ?? '');
    if (type == PrinterConnectionType.network) {
      await TokenStorage.write(_kIp, ipAddress ?? '');
      await TokenStorage.write(_kPort, (port ?? 9100).toString());
      await TokenStorage.delete(_kMac);
    } else {
      await TokenStorage.write(_kMac, macAddress ?? '');
      await TokenStorage.delete(_kIp);
    }
    state = state.copyWith(
      config: state.config.copyWith(
        connectionType: type,
        macAddress: type == PrinterConnectionType.bluetooth ? macAddress : null,
        ipAddress: type == PrinterConnectionType.network ? ipAddress : null,
        port: type == PrinterConnectionType.network ? port : state.config.port,
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

  Future<void> disconnect() async {
    if (state.config.connectionType == PrinterConnectionType.bluetooth) {
      await PrintBluetoothThermal.disconnect;
    } else {
      await _closeSocket();
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
    await TokenStorage.write(_kStore, config.storeName);
    await TokenStorage.write(_kAddr, config.storeAddress);
    await TokenStorage.write(_kPhone, config.storePhone);
    state = state.copyWith(config: config);
  }

  Future<void> printReceipt(OrderModel order) async {
    final copies = state.config.printCopies.clamp(1, 9);
    final bytes = await ReceiptFormatter.formatBytes(
      order: order,
      storeName: state.config.storeName,
      storeAddress: state.config.storeAddress,
      storePhone: state.config.storePhone,
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
  (ref) => PrinterNotifier(),
);
