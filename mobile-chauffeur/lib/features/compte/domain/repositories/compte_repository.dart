import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/profil.dart';
import '../entities/solde.dart';

abstract interface class CompteRepository {
  Future<Either<Failure, Profil>> getProfil();
  Future<Either<Failure, Solde>> getSolde();

  /// Dernières réponses reçues, sans appel au serveur ; `null` si aucune.
  Future<Profil?> getProfilEnCache();
  Future<Solde?> getSoldeEnCache();
}
