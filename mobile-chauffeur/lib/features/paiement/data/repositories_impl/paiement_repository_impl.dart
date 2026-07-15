import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/paiement.dart';
import '../../domain/repositories/paiement_repository.dart';
import '../datasources/paiement_remote_datasource.dart';

class PaiementRepositoryImpl implements PaiementRepository {
  final PaiementRemoteDatasource _datasource;
  const PaiementRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, Paiement>> initier({
    required String typeCible,
    required int cibleId,
    required String canal,
    required String telephone,
  }) =>
      guard(() => _datasource.initier(
            typeCible: typeCible,
            cibleId: cibleId,
            canal: canal,
            telephone: telephone,
          ));

  @override
  Future<Either<Failure, Paiement>> statut(String reference) =>
      guard(() => _datasource.statut(reference));
}
