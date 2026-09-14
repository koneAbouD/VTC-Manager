import 'package:fpdart/fpdart.dart';

import '../../core/error/failure.dart';
import '../../core/models/encaissement_lot.dart';
import '../../core/widgets/encaissement_lot_dialog.dart';

/// Encaissement de masse où chaque ligne peut couvrir **deux** créances du même
/// jour : la recette et la cotisation. Le guichet saisit un montant par
/// journée ; ce qui dépasse la créance ouverte revient à sa sœur.
///
/// Chaque journée part comme **un versement** : sa recette et sa cotisation
/// passent ensemble ou pas du tout, en un seul envoi pour tout le lot. Une
/// journée n'est donc jamais encaissée à moitié : ce qui est passé quitte la
/// feuille, ce qui a échoué se renvoie tel quel, sans rien rejouer.
///
/// L'envoi rend un verdict par versement, **dans l'ordre** où ils ont été remis
/// — c'est ce qui permet de rendre chaque verdict à sa ligne, même quand la
/// recette ne reçoit rien et que seule la cotisation part.
typedef EnvoiVersements = Future<Either<Failure, ResultatEncaissementLot>> Function(
  List<VersementDeLigne> versements,
  SaisieLot saisie,
);

/// Ce qu'une journée du lot envoie : la part de sa créance, et celle de sa
/// sœur du même jour s'il lui en revient.
class VersementDeLigne {
  final int ligneId;
  final double principal;
  final int? jumelleId;
  final double jumelle;

  const VersementDeLigne({
    required this.ligneId,
    required this.principal,
    this.jumelleId,
    this.jumelle = 0,
  });
}

/// Ce qu'une ligne a effectivement encaissé au terme du lot : la part revenue
/// à la créance affichée, celle revenue à sa sœur du même jour, et ce qui
/// reste dû après coup. De quoi rédiger le reçu du chauffeur.
class ImputationLot {
  final int ligneId;
  final double principal;
  final double jumelle;
  final double restant;

  const ImputationLot({
    required this.ligneId,
    required this.principal,
    required this.jumelle,
    required this.restant,
  });

  double get total => principal + jumelle;
}

class ExecuteurLotJumele {
  final Map<int, LigneLotEncaissable> _lignes;
  final EnvoiVersements envoyer;

  /// Ce que chaque créance peut encore recevoir, décrémenté quand un versement
  /// passe : c'est le reste dû que le reçu annonce.
  final Map<int, _Restants> _restants;

  /// Ce que chaque ligne a reçu : la matière des reçus.
  final Map<int, _Impute> _imputees = {};

  /// La dernière saisie appliquée — mode, date, référence sont communs au lot
  /// et n'existent nulle part ailleurs une fois la feuille refermée.
  SaisieLot? _derniereSaisie;

  SaisieLot? get derniereSaisie => _derniereSaisie;

  /// Ce qui est réellement passé, ligne par ligne. Vide tant qu'aucun
  /// versement n'a été accepté.
  List<ImputationLot> get imputationsReussies => [
        for (final e in _imputees.entries)
          ImputationLot(
            ligneId: e.key,
            principal: e.value.principal,
            jumelle: e.value.jumelle,
            restant: _restants[e.key]?.total ?? 0,
          ),
      ];

  ExecuteurLotJumele({
    required List<LigneLotEncaissable> lignes,
    required this.envoyer,
  })  : _lignes = {for (final l in lignes) l.id: l},
        _restants = {
          for (final l in lignes)
            l.id: _Restants(l.restant, l.jumelle?.restant ?? 0),
        };

  Future<IssueLot> executer(SaisieLot saisie) async {
    _derniereSaisie = saisie;

    final versements = <VersementDeLigne>[];
    for (final montantLigne in saisie.lignes) {
      final ligne = _lignes[montantLigne.ligneId];
      final restants = _restants[montantLigne.ligneId];
      if (ligne == null || restants == null) continue;

      final part = montantLigne.montant.clamp(0.0, restants.principal);
      final surplus = ligne.jumelle == null
          ? 0.0
          : (montantLigne.montant - part).clamp(0.0, restants.jumelle);
      if (part <= 0 && surplus <= 0) continue;

      versements.add(VersementDeLigne(
        ligneId: ligne.id,
        principal: part,
        jumelleId: surplus > 0 ? ligne.jumelle!.id : null,
        jumelle: surplus,
      ));
    }
    if (versements.isEmpty) return const IssueLot();

    final envoi = await envoyer(versements, saisie);
    // Rien n'est parti : la feuille garde la saisie intacte.
    return envoi.fold(
      (echec) => IssueLot.erreur(echec.message),
      (lot) => _appliquer(versements, lot),
    );
  }

  /// Un verdict par journée. Un versement accepté l'est en entier — recette et
  /// cotisation — et ne sera plus jamais proposé ; un versement refusé ne l'est
  /// pas davantage à moitié, et se renvoie tel quel.
  IssueLot _appliquer(List<VersementDeLigne> versements, ResultatEncaissementLot lot) {
    final verdicts = {for (final r in lot.resultats) r.ligneId: r};
    final reussies = <int>{};
    final echecs = <int, String>{};

    for (final v in versements) {
      final verdict = verdicts[v.ligneId];
      if (verdict?.succes ?? false) {
        final restants = _restants[v.ligneId]!;
        restants.principal -= v.principal;
        restants.jumelle -= v.jumelle;
        final cumul = _imputees.putIfAbsent(v.ligneId, () => _Impute());
        cumul.principal += v.principal;
        cumul.jumelle += v.jumelle;
        reussies.add(v.ligneId);
      } else {
        echecs[v.ligneId] = verdict?.message ?? 'Encaissement refusé.';
      }
    }

    return IssueLot(reussies: reussies, echecs: echecs);
  }
}

/// Rend à chaque journée le verdict de son versement.
///
/// Le serveur répond dans l'ordre des versements remis, sans nommer la ligne
/// affichée : c'est l'ordre qui fait le lien. Une journée dont la recette ne
/// recevait rien — tout est allé à la cotisation — retrouve ainsi quand même
/// son verdict.
ResultatEncaissementLot verdictsParLigne(
  List<VersementDeLigne> versements,
  List<({bool succes, String? message})> verdicts,
) {
  final resultats = [
    for (var i = 0; i < versements.length && i < verdicts.length; i++)
      ResultatLigneLot(
        ligneId: versements[i].ligneId,
        succes: verdicts[i].succes,
        message: verdicts[i].message,
      ),
  ];
  final reussis = resultats.where((r) => r.succes).length;
  return ResultatEncaissementLot(
    reussis: reussis,
    echecs: resultats.length - reussis,
    resultats: resultats,
  );
}

class _Impute {
  double principal = 0;
  double jumelle = 0;
}

class _Restants {
  double principal;
  double jumelle;

  _Restants(this.principal, this.jumelle);

  double get total => principal + jumelle;
}
