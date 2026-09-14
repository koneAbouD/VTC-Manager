import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/encaissement_ligne_dialog.dart';
import '../../core/widgets/encaissement_lot_dialog.dart';
import '../../features/cotisation/domain/entities/ligne_cotisation.dart';
import '../../features/cotisation/domain/entities/ligne_cotisation_filtres.dart';
import '../../features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import '../../features/recette/domain/entities/ligne_recette.dart';
import '../../features/recette/presentation/providers/ligne_recette_provider.dart';
import '../../features/operation_financiere/domain/enums/mode_paiement.dart';
import '../../features/versement/domain/entities/encaissement_versement.dart';
import '../../features/versement/domain/repositories/versement_repository.dart';
import '../../features/versement/presentation/providers/versement_provider.dart';

// ── Palette des deux natures de ligne (identique aux fiches détail) ───────────

const _kVertRecette     = Color(0xFF2E7D32);
const _kOrangeCotisation = Color(0xFFE65100);

final _jourFmt = DateFormat('dd/MM/yyyy');

/// Le chauffeur règle presque toujours d'un seul versement la recette et la
/// cotisation du jour. Depuis une fiche, on propose donc la ligne sœur : même
/// jour, même véhicule, même chauffeur — l'invariant « un véhicule par jour »
/// garantit qu'il n'y en a qu'une par nature.
///
/// Ces recherches renvoient `null` s'il n'y a rien à proposer, mais aussi si
/// l'appel échoue : la commodité ne doit jamais empêcher d'encaisser la ligne
/// que l'utilisateur a ouverte.

/// Cotisation du même jour, à proposer depuis une fiche recette.
Future<LigneJumelleEncaissement?> chercherCotisationDuMemeJour(
  WidgetRef ref,
  LigneRecette ligne,
) async {
  final jour = DateUtils.dateOnly(ligne.dateRecette);
  final repo = ref.read(ligneCotisationRepositoryProvider);

  final resultat = await repo.getLignes(LigneCotisationFiltres(
    vehiculeId:  ligne.vehiculeId,
    chauffeurId: ligne.chauffeurId,
    dateDebut:   jour,
    dateFin:     jour,
  ));

  // Pris maintenant : la feuille s'ouvre ensuite, et le versement part plus tard.
  final versements = ref.read(versementRepositoryProvider);

  return resultat.fold((_) => null, (lignes) {
    for (final c in lignes) {
      if (!c.estActive || c.id == null) continue;
      if (DateUtils.dateOnly(c.dateCotisation) != jour) continue;
      final restant =
          c.montantRestant ?? (c.montantDu - c.montantEncaisse);
      if (restant <= 0) continue;

      return LigneJumelleEncaissement(
        libelle:        'Encaisser aussi la cotisation du même jour',
        titre:          c.nomCotisation,
        sousTitre:      _jourFmt.format(c.dateCotisation),
        montantRestant: restant,
        couleur:        _kOrangeCotisation,
        icone:          Icons.analytics_outlined,
        encaisserEnsemble: (principale, jumelle) => _encaisserVersement(
          versements,
          recette: principale == null
              ? null
              : PartVersement(ligneId: ligne.id!, montant: principale.montant),
          cotisation: PartVersement(ligneId: c.id!, montant: jumelle.montant),
          saisie: jumelle,
        ),
      );
    }
    return null;
  });
}

/// Recette du même jour, à proposer depuis une fiche cotisation.
Future<LigneJumelleEncaissement?> chercherRecetteDuMemeJour(
  WidgetRef ref,
  LigneCotisation ligne,
) async {
  final jour = DateUtils.dateOnly(ligne.dateCotisation);
  final repo = ref.read(ligneRecetteRepositoryProvider);

  final resultat = await repo.getLignes(
    vehiculeId:  ligne.vehiculeId,
    chauffeurId: ligne.chauffeurId,
    dateDebut:   jour,
    dateFin:     jour,
  );

  final versements = ref.read(versementRepositoryProvider);

  return resultat.fold((_) => null, (lignes) {
    for (final r in lignes) {
      if (!r.estActive || r.id == null) continue;
      if (DateUtils.dateOnly(r.dateRecette) != jour) continue;
      // Recette sans montant attendu : son restant est inconnu, on ne sait pas
      // quelle part lui revient — inutile de la proposer ici.
      final restant = r.montantRestant;
      if (restant == null || restant <= 0) continue;

      return LigneJumelleEncaissement(
        libelle:        'Encaisser aussi la recette du même jour',
        titre:          'Recette',
        sousTitre:      _jourFmt.format(r.dateRecette),
        montantRestant: restant,
        couleur:        _kVertRecette,
        icone:          Icons.account_balance_wallet_outlined,
        encaisserEnsemble: (principale, jumelle) => _encaisserVersement(
          versements,
          recette: PartVersement(ligneId: r.id!, montant: jumelle.montant),
          cotisation: principale == null
              ? null
              : PartVersement(ligneId: ligne.id!, montant: principale.montant),
          saisie: jumelle,
        ),
      );
    }
    return null;
  });
}

// ── Recherche en lot ──────────────────────────────────────────────────────────

/// Les cotisations sœurs de tout un lot de recettes, en **une seule requête** :
/// on interroge la plage couverte par la sélection, puis on apparie en mémoire
/// sur le triplet véhicule + chauffeur + jour.
///
/// La clé du résultat est l'identifiant de la ligne de recette. Une ligne sans
/// cotisation ouverte n'y figure pas ; un appel qui échoue rend une carte vide,
/// la commodité ne devant jamais empêcher l'encaissement du lot.
///
/// Il n'y a pas de symétrique : le lot lancé depuis la liste des cotisations
/// n'encaisse que des cotisations.

/// Cotisations du même jour pour un lot de recettes.
Future<Map<int, JumelleLot>> chercherCotisationsDuMemeJour(
  WidgetRef ref,
  List<LigneRecette> lignes,
) async {
  if (lignes.isEmpty) return {};

  final jours = lignes.map((l) => DateUtils.dateOnly(l.dateRecette)).toList()
    ..sort();
  final vehicules = lignes.map((l) => l.vehiculeId).toSet();

  final resultat =
      await ref.read(ligneCotisationRepositoryProvider).getLignes(
            LigneCotisationFiltres(
              // Un seul véhicule dans le lot : autant que le serveur filtre.
              vehiculeId: vehicules.length == 1 ? vehicules.first : null,
              dateDebut:  jours.first,
              dateFin:    jours.last,
            ),
          );

  return resultat.fold((_) => <int, JumelleLot>{}, (candidates) {
    final disponibles = <String, LigneCotisation>{};
    for (final c in candidates) {
      if (!c.estActive || c.id == null) continue;
      final restant = c.montantRestant ?? (c.montantDu - c.montantEncaisse);
      if (restant <= 0) continue;
      disponibles.putIfAbsent(
          _cle(c.vehiculeId, c.chauffeurId, c.dateCotisation), () => c);
    }

    final jumelles = <int, JumelleLot>{};
    for (final l in lignes) {
      final cle = _cle(l.vehiculeId, l.chauffeurId, l.dateRecette);
      final c = disponibles.remove(cle);
      if (c == null) continue;
      jumelles[l.id!] = JumelleLot(
        id:      c.id!,
        libelle: c.nomCotisation,
        restant: c.montantRestant ?? (c.montantDu - c.montantEncaisse),
      );
    }
    return jumelles;
  });
}

/// Une créance par véhicule, par chauffeur et par jour : l'invariant « un
/// véhicule par jour » fait de ce triplet une clé sûre.
String _cle(int vehiculeId, int chauffeurId, DateTime jour) =>
    '$vehiculeId/$chauffeurId/${DateUtils.dateOnly(jour).toIso8601String()}';

// ── Un billet pour deux créances ──────────────────────────────────────────────

/// Encaisse la recette et la cotisation du jour d'un seul versement : le serveur
/// les rattache à la même pièce de caisse, et refuse les deux si l'une l'est.
/// La saisie commune — mode, date, référence — vient de la feuille.
Future<String?> _encaisserVersement(
  VersementRepository versements, {
  PartVersement? recette,
  PartVersement? cotisation,
  required SaisieEncaissement saisie,
}) async {
  final resultat = await versements.encaisser(
    recette: recette,
    cotisation: cotisation,
    mode: saisie.mode == ModeEncaissementSaisie.mobileMoney
        ? ModePaiement.MOBILE_MONEY
        : ModePaiement.ESPECES,
    date: saisie.date,
    reference: saisie.reference,
    commentaire: saisie.commentaire,
  );
  return resultat.fold((f) => f.message, (_) => null);
}
