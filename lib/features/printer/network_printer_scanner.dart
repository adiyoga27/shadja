import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

class NetworkPrinterDevice {
  const NetworkPrinterDevice({required this.ipAddress, this.name});
  final String ipAddress;
  final String? name;
}

/// Memindai jaringan lokal (subnet /24) untuk mencari printer yang
/// membuka port 9100 (port standar printer thermal ESC/POS via LAN).
class NetworkPrinterScanner {
  NetworkPrinterScanner._();

  static Future<List<NetworkPrinterDevice>> scan({
    Duration timeout = const Duration(milliseconds: 400),
    int port = 9100,
    int maxConcurrent = 30,
  }) async {
    final base = await _localBaseAddress();
    if (base == null) {
      throw const SocketException('Tidak dapat menemukan alamat IP lokal.');
    }

    final futures = <Future<NetworkPrinterDevice?>>[];
    for (var i = 1; i <= 254; i++) {
      futures.add(_probe('$base.$i', port, timeout));
    }

    final results = <NetworkPrinterDevice>[];
    var index = 0;
    while (index < futures.length) {
      final batch = <Future<NetworkPrinterDevice?>>[];
      for (var j = 0; j < maxConcurrent && index < futures.length; j++, index++) {
        batch.add(futures[index]);
      }
      final done = await Future.wait(batch);
      for (final d in done) {
        if (d != null) results.add(d);
      }
    }

    if (kDebugMode) {
      debugPrint('[NetPrinterScan] found ${results.length} device(s): $results');
    }
    return results;
  }

  static Future<NetworkPrinterDevice?> _probe(
      String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      await socket.close();
      return NetworkPrinterDevice(ipAddress: ip);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _localBaseAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NetPrinterScan] interface error: $e');
      }
    }
    return null;
  }
}
