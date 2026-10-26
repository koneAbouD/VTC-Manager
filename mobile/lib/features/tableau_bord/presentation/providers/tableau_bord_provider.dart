import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_cache/tmk_cache.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/tableau_bord_remote_datasource.dart';
import '../../data/models/tableau_bord_model.dart';

final tableauBordDatasourceProvider = Provider<TableauBordRemoteDatasource>(
  (ref) => TableauBordRemoteDatasource(ref.watch(apiClientProvider)),
);

/// Cadrage courant du tableau de bord : période observée et base comptable.
///
/// La base n'est pas un détail d'affichage. En CAISSE on lit ce qui est entré
/// et sorti — la vérité de la trésorerie ; en ENGAGEMENT ce qui est dû — la
/// vérité de l'activité. Un parc dont les chauffeurs versent en retard donne
/// deux images très différentes selon la base, et c'est précisément l'écart
/// entre les deux qui se lit dans le taux de recouvrement.
class TableauBordCadrage {
  final int annee;
  final int mois;
  final String base;

  const TableauBordCadrage({
    required this.annee,
    required this.mois,
    this.base = 'CAISSE',
  });

  factory TableauBordCadrage.moisCourant() {
    final now = DateTime.now();
    return TableauBordCadrage(annee: now.year, mois: now.month);
  }

  bool get estEngagement => base == 'ENGAGEMENT';

  TableauBordCadrage copyWith({int? annee, int? mois, String? base}) =>
      TableauBordCadrage(
        annee: annee ?? this.annee,
        mois: mois ?? this.mois,
        base: base ?? this.base,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TableauBordCadrage &&
          other.annee == annee &&
          other.mois == mois &&
          other.base == base);

  @override
  int get hashCode => Object.hash(annee, mois, base);
}

final tableauBordCadrageProvider = StateProvider<TableauBordCadrage>(
  (ref) => TableauBordCadrage.moisCourant(),
);

/// Photo de la période, cadrée par [tableauBordCadrageProvider].
/// Invalider le provider pour rafraîchir.
///
/// À l'ouverture, la dernière photo connue de ce cadrage s'affiche le temps
/// que le serveur réponde ; un rafraîchissement garde la photo affichée.
final tableauBordProvider =
    FutureProvider.autoDispose<TableauBordModel>((ref) async {
  final cadrage = ref.watch(tableauBordCadrageProvider);
  final ds = ref.watch(tableauBordDatasourceProvider);
  final enAttente = ds.getTableauBord(
    annee: cadrage.annee,
    mois: cadrage.mois,
    base: cadrage.base,
  );
  if (!ref.state.hasValue) {
    var actif = true;
    ref.onDispose(() => actif = false);
    await afficherEnAttendant<TableauBordModel>(
      enAttente: enAttente,
      cache: () => ds.getTableauBordEnCache(
        annee: cadrage.annee,
        mois: cadrage.mois,
        base: cadrage.base,
      ),
      afficher: (photo) {
        if (actif) ref.state = AsyncData(photo);
      },
    );
  }
  return enAttente;
});
