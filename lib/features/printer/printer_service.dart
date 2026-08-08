import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shadja/features/order/data/order_model.dart';
import 'package:shadja/features/printer/receipt_formatter.dart';
import 'package:shadja/core/storage/token_storage.dart';

enum PrinterConnectionStatus { disconnected, connecting, connected }

class PrinterConfig {
  const PrinterConfig({
    this.macAddress,
    this.name,
    this.paperWidth = 80,
    this.autoPrint = false,
    this.storeName = 'Shadja Restaurant',
    this.storeAddress = 'Jl. Contoh No. 123',
    this.storePhone = '08123456789',
  });

  final String? macAddress;
  final String? name;
  final int paperWidth;
  final bool autoPrint;
  final String storeName;
  final String storeAddress;
  final String storePhone;

  PrinterConfig copyWith({
    String? macAddress,
    String? name,
    int? paperWidth,
    bool? autoPrint,
    String? storeName,
    String? storeAddress,
    String? storePhone,
  }) =>
      PrinterConfig(
        macAddress: macAddress ?? this.macAddress,
        name: name ?? this.name,
        paperWidth: paperWidth ?? this.paperWidth,
        autoPrint: autoPrint ?? this.autoPrint,
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

  static const _kMac = 'printer_mac';
  static const _kName = 'printer_name';
  static const _kPaper = 'printer_paper';
  static const _kAuto = 'printer_auto';
  static const _kStore = 'printer_store';
  static const _kAddr = 'printer_addr';
  static const _kPhone = 'printer_phone';

  Future<void> _loadConfig() async {
    final mac = await TokenStorage.read(_kMac);
    final name = await TokenStorage.read(_kName);
    final paper = int.tryParse(await TokenStorage.read(_kPaper) ?? '80') ?? 80;
    final auto = (await TokenStorage.read(_kAuto)) == 'true';
    final store = await TokenStorage.read(_kStore) ?? 'Shadja Restaurant';
    final addr = await TokenStorage.read(_kAddr) ?? 'Jl. Contoh No. 123';
    final phone = await TokenStorage.read(_kPhone) ?? '08123456789';

    state = PrinterState(
      config: PrinterConfig(
        macAddress: mac,
        name: name,
        paperWidth: paper,
        autoPrint: auto,
        storeName: store,
        storeAddress: addr,
        storePhone: phone,
      ),
      status: PrinterConnectionStatus.disconnected,
    );

    if (mac != null && mac.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[Printer] _loadConfig: auto-connecting to $mac ($name)');
      }
      await Future.delayed(const Duration(milliseconds: 800));
      await connect(mac);
    }
  }

  Future<void> setPrinter(String macAddress, String name) async {
    await TokenStorage.write(_kMac, macAddress);
    await TokenStorage.write(_kName, name);
    state = state.copyWith(
      config: state.config.copyWith(macAddress: macAddress, name: name),
      status: PrinterConnectionStatus.connecting,
    );
    await connect(macAddress);
  }

  Future<void> connect(String macAddress) async {
    state = state.copyWith(
        status: PrinterConnectionStatus.connecting, error: null);
    try {
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

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    state = state.copyWith(status: PrinterConnectionStatus.disconnected);
  }

  Future<void> forgetPrinter() async {
    await disconnect();
    await TokenStorage.delete(_kMac);
    await TokenStorage.delete(_kName);
    state = state.copyWith(
      config: PrinterConfig(
        macAddress: null,
        name: null,
        paperWidth: state.config.paperWidth,
        autoPrint: state.config.autoPrint,
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
    await TokenStorage.write(_kStore, config.storeName);
    await TokenStorage.write(_kAddr, config.storeAddress);
    await TokenStorage.write(_kPhone, config.storePhone);
    state = state.copyWith(config: config);
  }

  Future<void> printReceipt(OrderModel order) async {
    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      throw PrinterException('Printer belum terhubung.');
    }

    final bytes = await ReceiptFormatter.formatBytes(
      order: order,
      storeName: state.config.storeName,
      storeAddress: state.config.storeAddress,
      storePhone: state.config.storePhone,
      paperWidth: state.config.paperWidth,
    );

    final result = await PrintBluetoothThermal.writeBytes(bytes);
    if (!result) {
      throw PrinterException('Gagal mengirim data ke printer.');
    }
  }

  Future<void> printTest() async {
    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      throw PrinterException('Printer belum terhubung.');
    }

    final bytes = await ReceiptFormatter.testBytes(
      storeName: state.config.storeName,
      paperWidth: state.config.paperWidth,
    );

    final result = await PrintBluetoothThermal.writeBytes(bytes);
    if (!result) {
      throw PrinterException('Gagal mengirim test page ke printer.');
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
