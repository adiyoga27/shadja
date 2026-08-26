import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadja/app.dart';
import 'package:shadja/features/auth/data/auth_model.dart';
import 'package:shadja/features/auth/data/auth_repository.dart';
import 'package:shadja/features/auth/presentation/auth_provider.dart';

class _FakeAuthRepo implements AuthRepository {
  @override
  Future<UserModel?> currentUser() async => null;
  @override
  Future<UserModel> fetchProfile() async {
    throw AuthException('test');
  }
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
  testWidgets('App boots to splash and settles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(_FakeAuthRepo())],
        child: const ShadjaApp(),
      ),
    );
    expect(find.text('Shadja POS'), findsOneWidget);

    // Let the splash timer + async auth check run to completion.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // App did not crash and rendered a Scaffold.
    expect(find.byType(Scaffold), findsWidgets);
  });
}