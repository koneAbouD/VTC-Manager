import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/network/page_result.dart';
import '../entities/encaissement_cotisation.dart';
import '../entities/ligne_cotisation.dart';
import '../entities/ligne_cotisation_filtres.dart';
import '../entities/totaux_cotisation.dart';

abstract interface class LigneCotisationRepository {
  Future<Either<Failure, List<LigneCotisation>>> getLignes(LigneCotisationFiltres filtres);
  Future<Either<Failure, PageResult<LigneCotisation>>> getLignesPage(
      LigneCotisationFiltres filtres, {int page, int size});
  /// Cumuls de la sélection, calculés par le serveur sur toutes les lignes et
  /// non sur les pages chargées. Le statut des filtres est ignoré : ces
  /// montants servent justement à en choisir un.
  Future<Either<Failure, TotauxCotisation>> getTotaux(LigneCotisationFiltres filtres);
  Future<Either<Failure, LigneCotisation>> getLigneById(int id);
  Future<Either<Failure, EncaissementCotisation>> createEncaissement(int ligneId, EncaissementCotisation enc);
  Future<Either<Failure, LigneCotisation>> annuler(int id, String motif);

  /// Remet une ligne annulée en circulation : elle retrouve le statut que
  /// dictent ses versements. Refusé par le serveur si la période est clôturée.
  Future<Either<Failure, LigneCotisation>> restaurer(int id);
  Future<Either<Failure, List<LigneCotisation>>> generer({DateTime? date});
}
