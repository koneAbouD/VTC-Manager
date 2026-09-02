import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import '../../core/models/encaissement_lot.dart';
import '../../core/widgets/encaissement_lot_dialog.dart';

/// Envoi d'un lot où chaque ligne peut couvrir **deux** créances du même jour :
/// la recette et la cotisation. Le guichet saisit un montant par journée ; ce
/// qui dépasse la créance ouverte revient à sa sœur.
///
/// Les deux natures ont leur endpoint : un lot part par nature, dans l'ordre —
/// la ligne affichée d'abord, sa sœur ensuite. L'exécuteur suit ce qui est
/// réellement passé pour qu'un second envoi ne rejoue jamais une imputation
/// acceptée : c'est tout l'intérêt de le tenir ici plutôt que dans la feuille,
/// qui ne connaît, elle, qu'un montant par ligne.
typedef EnvoiLot = Future<Either<Failure, ResultatEncaissementLot>> Function(
  List<MontantLigne> imputations,
  SaisieLot saisie,
);

class ExecuteurLotJumele {
  final Map<int, LigneLotEncaissable> _lignes;
  final EnvoiLot envoyerPrincipal;
  final EnvoiLot envoyerJumelle;

  /// Ce que chaque créance peut encore recevoir, décrémenté à mesure que les
  /// imputations passent.
  final Map<int, _Restants> _restants;

  ExecuteurLotJumele({
    required List<LigneLotEncaissable> lignes,
    required this.envoyerPrincipal,
    required this.envoyerJumelle,
  })  : _lignes = {for (final l in lignes) l.id: l},
        _restants = {
          for (final l in lignes)
            l.id: _Restants(l.restant, l.jumelle?.restant ?? 0),
        };

  Future<IssueLot> executer(SaisieLot saisie) async {
    final imputationsPrincipales = <MontantLigne>[];
    final imputationsJumelles = <MontantLigne>[];
    final partPrincipale = <int, double>{};
    final partJumelle = <int, double>{};

    for (final montantLigne in saisie.lignes) {
      final ligne = _lignes[montantLigne.ligneId];
      final restants = _restants[montantLigne.ligneId];
      if (ligne == null || restants == null) continue;

      final part = montantLigne.montant.clamp(0.0, restants.principal);
      final surplus = (montantLigne.montant - part).clamp(0.0, restants.jumelle);

      if (part > 0) {
        imputationsPrincipales
            .add(MontantLigne(ligneId: ligne.id, montant: part));
        partPrincipale[ligne.id] = part;
      }
      if (surplus > 0 && ligne.jumelle != null) {
        imputationsJumelles
            .add(MontantLigne(ligneId: ligne.jumelle!.id, montant: surplus));
        partJumelle[ligne.id] = surplus;
      }
    }

    // ── Le lot de la nature affichée ────────────────────────────────────────
    var verdictsPrincipaux = <int, ResultatLigneLot>{};
    if (imputationsPrincipales.isNotEmpty) {
      final envoi = await envoyerPrincipal(imputationsPrincipales, saisie);
      final echec = envoi.fold<Failure?>((f) => f, (_) => null);
      // Rien n'est parti : la feuille garde la saisie intacte.
      if (echec != null) return IssueLot.erreur(echec.message);
      verdictsPrincipaux = _parLigne(envoi.getOrElse((_) => _vide));
    }

    // ── Le lot des créances sœurs ───────────────────────────────────────────
    var verdictsJumelles = <int, ResultatLigneLot>{};
    String? pannneJumelle;
    if (imputationsJumelles.isNotEmpty) {
      final envoi = await envoyerJumelle(imputationsJumelles, saisie);
      final echec = envoi.fold<Failure?>((f) => f, (_) => null);
      if (echec != null) {
        // La première moitié, elle, est passée : on ne peut pas prétendre que
        // rien n'a eu lieu. Le motif est porté par les lignes concernées.
        pannneJumelle = echec.message;
      } else {
        verdictsJumelles = _parLigne(envoi.getOrElse((_) => _vide));
      }
    }

    return _fusionner(
      saisie: saisie,
      partPrincipale: partPrincipale,
      partJumelle: partJumelle,
      verdictsPrincipaux: verdictsPrincipaux,
      verdictsJumelles: verdictsJumelles,
      panneJumelle: pannneJumelle,
    );
  }

  /// Un verdict par ligne : ce que chaque créance a reçu, ou pourquoi elle a
  /// été refusée.
  IssueLot _fusionner({
    required SaisieLot saisie,
    required Map<int, double> partPrincipale,
    required Map<int, double> partJumelle,
    required Map<int, ResultatLigneLot> verdictsPrincipaux,
    required Map<int, ResultatLigneLot> verdictsJumelles,
    required String? panneJumelle,
  }) {
    final reussies = <int>{};
    final echecs = <int, String>{};
    final restantsAjustes = <int, double>{};

    for (final id in {...partPrincipale.keys, ...partJumelle.keys}) {
      final ligne = _lignes[id]!;
      final restants = _restants[id]!;
      final partP = partPrincipale[id] ?? 0;
      final partJ = partJumelle[id] ?? 0;

      final verdictP = partP > 0 ? verdictsPrincipaux[id] : null;
      final verdictJ =
          partJ > 0 ? verdictsJumelles[ligne.jumelle?.id ?? -1] : null;

      final okP = partP == 0 || (verdictP?.succes ?? false);
      final okJ = partJ == 0 || (verdictJ?.succes ?? false);

      // Ce qui est passé ne sera plus proposé : un second envoi ne peut pas
      // rejouer une imputation acceptée.
      if (partP > 0 && okP) restants.principal -= partP;
      if (partJ > 0 && okJ) restants.jumelle -= partJ;

      if (okP && okJ) {
        reussies.add(id);
        continue;
      }

      final motifs = <String>[];
      if (!okP) motifs.add(verdictP?.message ?? 'Encaissement refusé.');
      if (!okJ) {
        final motif = verdictJ?.message ?? panneJumelle ?? 'Encaissement refusé.';
        motifs.add('${ligne.jumelle?.libelle ?? 'Créance du même jour'} : $motif');
      }
      echecs[id] = motifs.join(' · ');
      restantsAjustes[id] = restants.total;
    }

    return IssueLot(
      erreurGlobale: panneJumelle,
      reussies: reussies,
      echecs: echecs,
      restantsAjustes: restantsAjustes,
    );
  }

  static Map<int, ResultatLigneLot> _parLigne(ResultatEncaissementLot lot) =>
      {for (final r in lot.resultats) r.ligneId: r};

  static const _vide =
      ResultatEncaissementLot(reussis: 0, echecs: 0, resultats: []);
}

class _Restants {
  double principal;
  double jumelle;

  _Restants(this.principal, this.jumelle);

  double get total => principal + jumelle;
}
