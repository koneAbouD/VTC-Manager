import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/session_manager.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/entities/auth_tokens.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/password_login_usecase.dart';
import '../../domain/usecases/request_otp_usecase.dart';
import '../../domain/usecases/set_password_usecase.dart';
import '../../domain/usecases/verify_otp_usecase.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

// ── Datasource → Repository → Use cases ───────────────────────────────────────

final _authDatasourceProvider = Provider<AuthRemoteDatasource>(
  (ref) => AuthRemoteDatasource(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(_authDatasourceProvider)),
);

final _requestOtpUseCaseProvider = Provider(
  (ref) => RequestOtpUseCase(ref.watch(authRepositoryProvider)),
);
final _verifyOtpUseCaseProvider = Provider(
  (ref) => VerifyOtpUseCase(ref.watch(authRepositoryProvider)),
);
final _passwordLoginUseCaseProvider = Provider(
  (ref) => PasswordLoginUseCase(ref.watch(authRepositoryProvider)),
);
final _setPasswordUseCaseProvider = Provider(
  (ref) => SetPasswordUseCase(ref.watch(authRepositoryProvider)),
);

// ── Contrôleur d'état global d'authentification ───────────────────────────────

final authControllerProvider =
    NotifierProvider<AuthController, AuthStatus>(AuthController.new);

/// Détient l'état d'authentification global et pilote la session.
/// Les erreurs sont levées sous forme de message (String), présentées par les
/// pages via `messageFromError`.
class AuthController extends Notifier<AuthStatus> {
  late final SecureStorage _storage;

  @override
  AuthStatus build() {
    _storage = ref.watch(secureStorageProvider);
    return AuthStatus.unknown;
  }

  Future<void> bootstrap() async {
    if (await _storage.hasAccessToken()) {
      SessionManager.instance.start();
      state = AuthStatus.authenticated;
    } else {
      state = AuthStatus.unauthenticated;
    }
  }

  Future<void> requestOtp(String telephone) async {
    final result = await ref.read(_requestOtpUseCaseProvider).call(telephone);
    result.fold((f) => throw f.message, (_) {});
  }

  Future<void> verifyOtp(String telephone, String code) async {
    final result = await ref.read(_verifyOtpUseCaseProvider).call(telephone, code);
    await result.fold((f) => throw f.message, _persisterEtActiver);
  }

  Future<void> passwordLogin(String identifiant, String motDePasse) async {
    final result =
        await ref.read(_passwordLoginUseCaseProvider).call(identifiant, motDePasse);
    await result.fold((f) => throw f.message, _persisterEtActiver);
  }

  Future<void> setPassword(String motDePasse) async {
    final result = await ref.read(_setPasswordUseCaseProvider).call(motDePasse);
    result.fold((f) => throw f.message, (_) {});
  }

  Future<void> _persisterEtActiver(AuthTokens tokens) async {
    await _storage.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresInSeconds: tokens.expiresInSeconds,
    );
    SessionManager.instance.start();
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    SessionManager.instance.stop();
    await _storage.clearTokens();
    state = AuthStatus.unauthenticated;
  }
}
