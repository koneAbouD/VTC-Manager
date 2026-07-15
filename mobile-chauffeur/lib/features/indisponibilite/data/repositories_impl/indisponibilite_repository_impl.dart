import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/indisponibilite.dart';
import '../../domain/entities/remplacant.dart';
import '../../domain/repositories/indisponibilite_repository.dart';
import '../datasources/indisponibilite_remote_datasource.dart';

class IndisponibiliteRepositoryImpl implements IndisponibiliteRepository {
  final IndisponibiliteRemoteDatasource _datasource;
  const IndisponibiliteRepositoryImpl(this._datasource);

  @override
  Future<Either<Failure, List<Indisponibilite>>> getIndisponibilites() =>
      guard(() => _datasource.getIndisponibilites());

  @override
  Future<Either<Failure, List<Remplacant>>> getRemplacants() =>
      guard(() => _datasource.getRemplacants());

  @override
  Future<Either<Failure, Indisponibilite>> declarer({
    required int chauffeurRemplacantId,
    required String dateDebut,
    String? dateFin,
    String? motif,
    String? commentaire,
  }) =>
      guard(() => _datasource.declarer(
            chauffeurRemplacantId: chauffeurRemplacantId,
            dateDebut: dateDebut,
            dateFin: dateFin,
            motif: motif,
            commentaire: commentaire,
          ));

  @override
  Future<Either<Failure, Indisponibilite>> terminer(int id) =>
      guard(() => _datasource.terminer(id));
}
