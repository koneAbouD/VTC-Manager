import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../entities/indisponibilite.dart';
import '../entities/remplacant.dart';

abstract interface class IndisponibiliteRepository {
  Future<Either<Failure, List<Indisponibilite>>> getIndisponibilites();
  Future<Either<Failure, List<Remplacant>>> getRemplacants();
  Future<Either<Failure, Indisponibilite>> declarer({
    required int chauffeurRemplacantId,
    required String dateDebut,
    String? dateFin,
    String? motif,
    String? commentaire,
  });
  Future<Either<Failure, Indisponibilite>> terminer(int id);
}
