import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/forgot_password_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/refresh_token_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import 'auth_state.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────

final secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(secureStorageProvider)),
);

// ── Datasource → Repository (injection de dépendances) ──────────────────────

final authRemoteDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    ref.watch(authRemoteDatasourceProvider),
    ref.watch(secureStorageProvider),
  ),
);

// ── Use cases ───────────────────────────────────────────────────────────────

final loginUseCaseProvider = Provider(
  (ref) => LoginUseCase(ref.watch(authRepositoryProvider)),
);
final registerUseCaseProvider = Provider(
  (ref) => RegisterUseCase(ref.watch(authRepositoryProvider)),
);
final logoutUseCaseProvider = Provider(
  (ref) => LogoutUseCase(ref.watch(authRepositoryProvider)),
);
final refreshTokenUseCaseProvider = Provider(
  (ref) => RefreshTokenUseCase(ref.watch(authRepositoryProvider)),
);
final forgotPasswordUseCaseProvider = Provider(
  (ref) => ForgotPasswordUseCase(ref.watch(authRepositoryProvider)),
);

// ── Notifier ─────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final LoginUseCase _login;
  final RegisterUseCase _register;
  final LogoutUseCase _logout;
  final RefreshTokenUseCase _refresh;
  final ForgotPasswordUseCase _forgotPassword;
  final AuthRepository _repository;

  AuthNotifier({
    required LoginUseCase login,
    required RegisterUseCase register,
    required LogoutUseCase logout,
    required RefreshTokenUseCase refresh,
    required ForgotPasswordUseCase forgotPassword,
    required AuthRepository repository,
  })  : _login = login,
        _register = register,
        _logout = logout,
        _refresh = refresh,
        _forgotPassword = forgotPassword,
        _repository = repository,
        super(const AuthInitial());

  /// Vérifié au démarrage de l'app.
  Future<void> bootstrap() async {
    final authenticated = await _repository.isAuthenticated();
    if (!authenticated) {
      state = const AuthUnauthenticated();
      return;
    }
    // Tenter un refresh pour valider la session
    final result = await _refresh.call();
    result.fold(
      (_) => state = const AuthUnauthenticated(),
      (_) => state = const AuthAuthenticated(''),
    );
  }

  Future<void> login(String username, String password) async {
    state = const AuthLoading();
    final result = await _login.call(username, password);
    result.fold(
      (failure) => state = AuthError(failure.message),
      (_) => state = AuthAuthenticated(username),
    );
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    state = const AuthLoading();
    final result = await _register.call(
      username: username,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    result.fold(
      (failure) => state = AuthError(failure.message),
      (_) => state = const AuthUnauthenticated(), // redirige vers login
    );
  }

  Future<void> logout() async {
    await _logout.call();
    state = const AuthUnauthenticated();
  }

  Future<String?> forgotPassword(String email) async {
    final result = await _forgotPassword.call(email);
    return result.fold((f) => f.message, (_) => null);
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    login: ref.watch(loginUseCaseProvider),
    register: ref.watch(registerUseCaseProvider),
    logout: ref.watch(logoutUseCaseProvider),
    refresh: ref.watch(refreshTokenUseCaseProvider),
    forgotPassword: ref.watch(forgotPasswordUseCaseProvider),
    repository: ref.watch(authRepositoryProvider),
  );
});
