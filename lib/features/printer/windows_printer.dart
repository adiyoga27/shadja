import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Printer yang terpasang (installed) di Windows, diambil dari print spooler.
class WindowsPrinterDevice {
  const WindowsPrinterDevice({
    required this.name,
    this.driver,
    this.port,
  });

  final String name;
  final String? driver;
  final String? port;

  String get displayName => name;
}

class WindowsPrinterException implements Exception {
  WindowsPrinterException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Mencetak data mentah (RAW ESC/POS) ke printer Windows via print spooler
/// (winspool.drv). Printer harus sudah terinstal drivernya di Windows.
class WindowsPrinterService {
  WindowsPrinterService._();

  static final WindowsPrinterService instance = WindowsPrinterService._();

  int? _handle;

  bool get isConnected => _handle != null && _handle != 0;

  void _ensureWindows() {
    if (!Platform.isWindows) {
      throw WindowsPrinterException(
          'Mode USB Windows hanya didukung saat aplikasi berjalan di Windows.');
    }
  }

  /// Menampilkan daftar printer lokal + koneksi jaringan yang terpasang
  /// di Windows (muncul di "Printers & Scanners").
  static List<WindowsPrinterDevice> listPrinters() {
    if (!Platform.isWindows) return const [];

    const flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
    final needed = calloc<Uint32>();
    final returned = calloc<Uint32>();

    var ok = EnumPrinters(flags, nullptr, 2, nullptr, 0, needed, returned);
    if (ok == 0 && GetLastError() != ERROR_INSUFFICIENT_BUFFER) {
      final err = GetLastError();
      calloc.free(needed);
      calloc.free(returned);
      throw WindowsPrinterException(
          'Gagal membaca daftar printer Windows (error $err).');
    }

    final buffer = calloc<Uint8>(needed.value);
    ok = EnumPrinters(flags, nullptr, 2, buffer, needed.value, needed,
        returned);
    if (ok == 0) {
      final err = GetLastError();
      calloc.free(buffer);
      calloc.free(needed);
      calloc.free(returned);
      throw WindowsPrinterException(
          'Gagal membaca daftar printer Windows (error $err).');
    }

    final devices = <WindowsPrinterDevice>[];
    for (var i = 0; i < returned.value; i++) {
      final info = (buffer.cast<PRINTER_INFO_2>() + i).ref;
      final name = info.pPrinterName.toDartString();
      if (name.isEmpty) continue;
      devices.add(WindowsPrinterDevice(
        name: name,
        driver: info.pDriverName.toDartString(),
        port: info.pPortName.toDartString(),
      ));
    }

    calloc.free(buffer);
    calloc.free(needed);
    calloc.free(returned);
    return devices;
  }

  /// Membuka handle ke antrean printer. "Terhubung" = printer tersedia.
  void connect(String printerName) {
    _ensureWindows();
    close();

    final namePtr = printerName.toNativeUtf16();
    final handleOut = calloc<IntPtr>();
    final defaults = calloc<PRINTER_DEFAULTS>();
    defaults.ref.DesiredAccess = PRINTER_ACCESS_USE;

    final ok = OpenPrinter(namePtr, handleOut, defaults);

    calloc.free(namePtr);
    calloc.free(defaults);

    if (ok == 0) {
      final err = GetLastError();
      calloc.free(handleOut);
      throw WindowsPrinterException(
          'Tidak dapat mengakses printer "$printerName" (error $err). '
          'Pastikan printer terhubung & menyala.');
    }

    _handle = handleOut.value;
    calloc.free(handleOut);
  }

  /// Mengirim data mentah (RAW) ke printer via spooler.
  void printRaw(Uint8List bytes) {
    _ensureWindows();
    final handle = _handle;
    if (handle == null || handle == 0) {
      throw WindowsPrinterException('Printer belum terhubung.');
    }

    final docName = 'Shadja Struk'.toNativeUtf16();
    final datatype = 'RAW'.toNativeUtf16();
    final docInfo = calloc<DOC_INFO_1>();
    docInfo.ref.pDocName = docName;
    docInfo.ref.pOutputFile = nullptr;
    docInfo.ref.pDatatype = datatype;

    void freeAll() {
      calloc.free(docInfo);
      calloc.free(docName);
      calloc.free(datatype);
    }

    try {
      final jobId = StartDocPrinter(handle, 1, docInfo);
      if (jobId == 0) {
        throw WindowsPrinterException(
            'Gagal memulai dokumen cetak (error ${GetLastError()}).');
      }

      if (StartPagePrinter(handle) == 0) {
        EndDocPrinter(handle);
        throw WindowsPrinterException(
            'Gagal memulai halaman cetak (error ${GetLastError()}).');
      }

      final written = calloc<Uint32>();
      final buffer = calloc<Uint8>(bytes.length);
      buffer.asTypedList(bytes.length).setAll(0, bytes);
      final ok = WritePrinter(handle, buffer, bytes.length, written);
      EndPagePrinter(handle);
      EndDocPrinter(handle);
      calloc.free(buffer);
      calloc.free(written);

      if (ok == 0) {
        throw WindowsPrinterException(
            'Gagal mengirim data ke printer (error ${GetLastError()}). '
            'Jika hasil cetak kacau, ganti driver printer ke "Generic / Text Only" '
            'di Windows, lalu pilih printer itu lagi.');
      }
    } finally {
      freeAll();
    }
  }

  void close() {
    final handle = _handle;
    _handle = null;
    if (handle != null && handle != 0) {
      ClosePrinter(handle);
    }
  }
}