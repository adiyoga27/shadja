import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadja/core/network/dio_client.dart';
import 'package:shadja/features/auth/data/auth_model.dart';
import 'package:shadja/features/auth/data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(dioClientProvider)),
);

enum AuthStatus { initial, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.isLoading = false,
    this.error,
  });

  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState()) {
    _checkInitial();
  }

  final AuthRepository _repo;

  Future<void> _checkInitial() async {
    try {
      final user = await _repo.currentUser();
      state = AuthState(
        status: user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: user,
      );
    } catch (e) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _repo.login(email: email, password: password);
      state = AuthState(
        status: AuthStatus.authenticated,
        user: res.user,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      if (kDebugMode) debugPrint('Login error: $e');
      state = state.copyWith(
          isLoading: false, error: 'Terjadi kesalahan. Coba lagi.');
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _repo.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: res.user,
      );
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Terjadi kesalahan. Coba lagi.');
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(error: null);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(authRepositoryProvider)),
);