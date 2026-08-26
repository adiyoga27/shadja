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
      fullScreen: true,
      center: true,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setFullScreen(true);
      await windowManager.show();
    });
  }
  initializeDateFormatting('id_ID').then((_) {
    runApp(const ProviderScope(child: ShadjaApp()));
  });
}