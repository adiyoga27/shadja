import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shadja/app.dart';
import 'package:shadja/features/auth/data/auth_model.dart';
import 'package:shadja/features/auth/data/auth_repository.dart';
import 'package:shadja/features/auth/presentation/auth_provider.dart';
import 'package:shadja/features/menu/data/menu_model.dart';
import 'package:shadja/features/menu/data/menu_repository.dart';
import 'package:shadja/features/menu/presentation/menu_provider.dart';

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

class _FakeMenuRepo implements MenuRepository {
  @override
  Future<List<MenuCategoryModel>> fetchMenu() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    return [
      MenuCategoryModel(
        id: 1,
        name: 'Makanan',
        menuItems: [
          for (var i = 1; i <= 12; i++)
            MenuItemModel(
              id: i,
              name: 'Menu $i',
              price: 10000 + i,
              image: null,
              categoryId: 1,
              categoryName: 'Makanan',
            ),
        ],
      ),
    ];
  }

  @override
  Future<MenuItemModel> fetchMenuItem(int id) async =>
      throw UnimplementedError();
}

void main() {
  testWidgets('kasir with real menu data at 1920x1027 does not freeze',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1027);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
          menuRepositoryProvider.overrideWithValue(_FakeMenuRepo()),
        ],
        child: const ShadjaApp(),
      ),
    );

    // Splash + auth.
    await tester.pump(const Duration(seconds: 3));
    // Menu load completes and grid rebuilds inside the shell LayoutBuilder.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    }

    expect(find.byType(Scaffold), findsWidgets);
    expect(find.text('Menu 1'), findsOneWidget);
  });
}