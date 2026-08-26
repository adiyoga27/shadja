import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadja/app.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      center: true,
      skipTaskbar: false,
      title: 'Shadja POS',
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      // Maksimalkan jendela (bukan fullscreen) sehingga title bar Windows
      // tetap tampil dengan tombol minimize/maximize/exit (X).
      await windowManager.show();
      await windowManager.maximize();
    });
    // Tindakan pencegahan bila SC_MAXIMIZE belum terproses saat window tampil.
    await Future.delayed(const Duration(milliseconds: 300));
    if (!await windowManager.isMaximized()) {
      await windowManager.maximize();
    }
  }
  initializeDateFormatting('id_ID').then((_) {
    runApp(const ProviderScope(child: ShadjaApp()));
  });
}