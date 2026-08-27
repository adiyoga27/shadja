import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadja/core/routing/app_router.dart';
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
  test(
      'GoRouter tidak dibuat ulang saat status auth berubah '
      '(mencegah duplicate GlobalKey navigator)', () async {
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
    ]);
    addTearDown(container.dispose);

    final routerBefore = container.read(goRouterProvider);

    // Status auth berubah beberapa kali: initial → authenticated (restore),
    // lalu usaha login gagal (tetap unauthenticated).
    container.read(authProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    container.read(authProvider.notifier).sessionExpired();
    container.read(authProvider.notifier).login('a@b.c', 'wrongpass');

    final routerAfter = container.read(goRouterProvider);
    expect(identical(routerBefore, routerAfter), isTrue);
  });
}