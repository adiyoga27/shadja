import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadja/app.dart';
import 'package:shadja/features/auth/data/auth_model.dart';
import 'package:shadja/features/auth/data/auth_repository.dart';
import 'package:shadja/features/auth/presentation/auth_provider.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> currentUser() async =>
      UserModel(id: 1, name: 'Admin', email: 'admin@shadja.my.id', role: 'admin');
  @override
  Future<UserModel> fetchProfile() async =>
      UserModel(id: 1, name: 'Admin', email: 'admin@shadja.my.id', role: 'admin');
  @override
  Future<AuthResponseModel> login(
      {required String email, required String password}) async {
    throw AuthException('test');
  }
  @override
  Future<void> logout() async {}
  @override
  Future<AuthResponseModel> register(
      {required String name,
      required String email,
      required String password,
      String? phone}) async {
    throw AuthException('test');
  }
}

void main() {
  testWidgets('shell survives window resize and sidebar toggle without layout mutation',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepo())],
        child: const ShadjaApp(),
      ),
    );

    // Splash + auth + navigate to shell.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // Simulate window maximize (mobile -> tablet landscape) and back.
    for (final size in const [Size(1920, 1027), Size(1024, 700), Size(1920, 1027)]) {
      tester.view.physicalSize = size;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }

    // Sidebar toggle must not overflow or mutate render tree.
    final toggle = find.byTooltip('Tampilkan / sembunyikan menu');
    expect(toggle, findsWidgets);
    for (var i = 0; i < 3; i++) {
      await tester.tap(toggle.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
  });
}