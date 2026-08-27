import 'package:dio/dio.dart';
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
      final cached = await _repo.currentUser();
      if (cached == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: cached,
      );
      try {
        // Validasi token ke server. Bila 401 (kedaluwarsa / tidak valid),
        // jangan pakai cache: minta login ulang.
        final fresh = await _repo.fetchProfile();
        state = AuthState(
          status: AuthStatus.authenticated,
          user: fresh,
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          state = AuthState(
            status: AuthStatus.unauthenticated,
            error: 'Sesi berakhir. Silakan login kembali.',
          );
          return;
        }
        // Offline / error lain: tetap pakai cache agar app tetap bisa dipakai.
        if (kDebugMode) debugPrint('Refresh profile gagal, pakai cache: $e');
      } catch (e) {
        if (kDebugMode) debugPrint('Refresh profile gagal, pakai cache: $e');
      }
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

  /// Dipanggil saat ada response 401 dari request mana pun (token tidak valid).
  /// Mengarahkan pengguna kembali ke halaman login.
  void sessionExpired() {
    if (state.status == AuthStatus.unauthenticated) return;
    state = AuthState(
      status: AuthStatus.unauthenticated,
      error: 'Sesi berakhir. Silakan login kembali.',
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final notifier = AuthNotifier(ref.read(authRepositoryProvider));
  ref.listen(sessionExpiredProvider, (prev, next) {
    if (next == true) {
      notifier.sessionExpired();
      ref.read(sessionExpiredProvider.notifier).state = false;
    }
  });
  return notifier;
});