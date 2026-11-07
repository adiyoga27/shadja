import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Mendeteksi thread UI yang berhenti berdetak, dari luar thread tersebut.
class StallDetector {
  StallDetector(DateTime now)
      : _lastTick = now,
        _lastCheck = now;

  /// Windows menandai jendela "Not Responding" setelah sekitar 5 detik.
  static const threshold = Duration(seconds: 3);

  DateTime _lastTick;
  DateTime _lastCheck;
  bool _stalled = false;

  /// Dipanggil berkala oleh watchdog. Mengembalikan pesan saat macet dimulai.
  String? onCheck(DateTime now) {
    // Watchdog sendiri ikut terhenti berarti PC sleep, bukan UI macet.
    final suspended = now.difference(_lastCheck) > threshold;
    _lastCheck = now;
    if (suspended) {
      _lastTick = now;
      return null;
    }
    if (_stalled || now.difference(_lastTick) < threshold) return null;
    _stalled = true;
    return 'UI macet lebih dari ${threshold.inSeconds} detik';
  }

  /// Dipanggil saat detak UI diterima. Mengembalikan pesan saat UI pulih.
  String? onTick(DateTime now) {
    final stalledFor = now.difference(_lastTick);
    _lastTick = now;
    if (!_stalled) return null;
    _stalled = false;
    return 'UI pulih setelah ${stalledFor.inSeconds} detik';
  }
}

/// Mengirim error aplikasi ke channel Telegram.
///
/// Token dan chat id masuk saat build lewat
/// `--dart-define-from-file=telegram.local.json` (file itu di-gitignore karena
/// repo ini publik). Tanpa keduanya, pelaporan nonaktif.
class ErrorReporter {
  ErrorReporter._();

  static const _botToken = String.fromEnvironment('TELEGRAM_BOT_TOKEN');
  static const _chatId = String.fromEnvironment('TELEGRAM_CHAT_ID');

  // Batas Telegram 4096 karakter per pesan.
  static const _maxLength = 3500;
  static const _dedupeWindow = Duration(minutes: 5);

  static final _lastSent = <String, DateTime>{};

  // Dio terpisah: tanpa interceptor aplikasi, supaya token login tidak ikut
  // terkirim dan kegagalan lapor tidak memicu laporan baru.
  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  @visibleForTesting
  static Future<void> Function(String text)? senderOverride;

  @visibleForTesting
  static void resetDedupe() => _lastSent.clear();

  static void install() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack, source: 'flutter');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack, source: 'async');
      return false;
    };
    unawaited(_startStallWatchdog());
  }

  // Watchdog berjalan di isolate sendiri: saat thread UI macet, kode di thread
  // itu tidak bisa melapor.
  static Future<void> _startStallWatchdog() async {
    if (!_isConfigured) return;
    final ready = ReceivePort();
    await Isolate.spawn(_watchdog, ready.sendPort, debugName: 'stall-watchdog');
    final ticks = await ready.first as SendPort;
    Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => ticks.send(null),
    );
  }

  static void _watchdog(SendPort toMain) {
    final detector = StallDetector(DateTime.now());
    void notify(String? message) {
      if (message != null) report(message, null, source: 'stall');
    }

    final ticks = ReceivePort()
      ..listen((_) => notify(detector.onTick(DateTime.now())));
    Timer.periodic(
      const Duration(seconds: 1),
      (_) => notify(detector.onCheck(DateTime.now())),
    );
    toMain.send(ticks.sendPort);
  }

  /// Hanya method, path, dan status yang dikirim. Header dan body tidak, karena
  /// berisi token login dan data pelanggan. 401 (sesi habis) dan 422 (validasi
  /// input) adalah alur normal, bukan error.
  static Future<void> reportDio(DioException e) async {
    final status = e.response?.statusCode;
    if (status == 401 || status == 422) return;
    final request = e.requestOptions;
    await report(
      '${request.method} ${request.path} -> ${status ?? e.type.name}',
      null,
      source: 'api',
    );
  }

  static Future<void> report(
    Object error,
    StackTrace? stack, {
    required String source,
  }) async {
    final send = senderOverride ?? (_isConfigured ? _send : null);
    if (send == null) return;

    // Error yang berulang (mis. saat rebuild) tidak boleh membanjiri channel.
    final key = '$source|$error';
    final now = DateTime.now();
    final last = _lastSent[key];
    if (last != null && now.difference(last) < _dedupeWindow) return;
    if (_lastSent.length >= 100) _lastSent.clear();
    _lastSent[key] = now;

    final mode = kReleaseMode ? 'release' : 'debug';
    var text = '[Shadja POS] $source | ${Platform.localHostname} | '
        '${Platform.operatingSystem} | $mode\n'
        '$now\n\n$error';
    if (stack != null) text += '\n\n$stack';
    if (text.length > _maxLength) text = text.substring(0, _maxLength);

    try {
      await send(text);
    } catch (e) {
      debugPrint('[ErrorReporter] gagal mengirim: ${e.runtimeType}');
    }
  }

  static bool get _isConfigured => _botToken.isNotEmpty && _chatId.isNotEmpty;

  static Future<void> _send(String text) => _dio.post(
        'https://api.telegram.org/bot$_botToken/sendMessage',
        data: {'chat_id': _chatId, 'text': text},
      );
}
