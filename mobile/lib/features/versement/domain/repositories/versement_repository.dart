import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../operation_financiere/domain/enums/mode_paiement.dart';
import '../entities/encaissement_versement.dart';
import '../entities/versement.dart';

abstract class VersementRepository {
  /// Encaisse un billet : la recette, la cotisation du jour, ou les deux —
  /// ensemble ou pas du tout.
  Future<Either<Failure, VersementEnregistre>> encaisser({
    PartVersement? recette,
    PartVersement? cotisation,
    required ModePaiement mode,
    required DateTime date,
    String? reference,
    String? commentaire,
  });

  /// Plusieurs versements d'un même geste de caisse, un verdict par versement.
  Future<Either<Failure, ResultatVersementLot>> encaisserLot({
    required List<ElementVersementLot> versements,
    required ModePaiement mode,
    required DateTime date,
    String? reference,
    String? commentaire,
  });

  Future<Either<Failure, Versement>> getVersement(String versementId);
}
