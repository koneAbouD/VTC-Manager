import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/token.dart';

/// Port d'authentification — interface pure.
/// La couche data en fournit l'implémentation.
abstract interface class AuthRepository {
  Future<Either<Failure, Token>> login(String username, String password);
  Future<Either<Failure, void>> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  });
  Future<Either<Failure, Token>> refreshToken();
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, void>> forgotPassword(String email);
  Future<bool> isAuthenticated();
}
