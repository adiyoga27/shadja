import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shadja/app.dart';

void main() {
  initializeDateFormatting('id_ID').then((_) {
    runApp(const ProviderScope(child: ShadjaApp()));
  });
}