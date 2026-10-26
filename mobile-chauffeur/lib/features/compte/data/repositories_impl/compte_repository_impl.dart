import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/profil.dart';
import '../../domain/entities/solde.dart';
import '../../domain/repositories/compte_repository.dart';
import '../datasources/compte_remote_datasource.dart';

class CompteRepositoryImpl implements CompteRepository {
  final CompteRemoteDatasource _datasource;
  const CompteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Profil>> getProfil() =>
      guard(() => _datasource.getProfil());

  @override
  Future<Either<Failure, Solde>> getSolde() =>
      guard(() => _datasource.getSolde());
}
