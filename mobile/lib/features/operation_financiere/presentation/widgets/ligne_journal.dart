import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/statut_operation.dart';

/// Une ligne du journal tel que le guichet le lit : une écriture seule, ou le
/// versement qui en rassemble plusieurs.
///
/// Le journal, lui, ne change pas : il garde une écriture par créance — la
/// recette au résultat, la cotisation en compte de tiers. Ce regroupement est
/// une manière de les montrer, jamais de les compter : les chips, les filtres
/// et les totaux continuent de lire chaque écriture pour ce qu'elle est.
sealed class LigneJournal {
  const LigneJournal();
}

class EcritureSeule extends LigneJournal {
  final OperationFinanciere operation;
  const EcritureSeule(this.operation);
}

class VersementRegroupe extends LigneJournal {
  /// La recette d'abord, puis la cotisation : l'ordre du guichet.
  final List<OperationFinanciere> ecritures;
  const VersementRegroupe(this.ecritures);

  /// L'écriture qu'ouvre un appui sur la ligne : son détail montre la sœur.
  OperationFinanciere get tete => ecritures.first;

  /// Ce que le billet atteste encore.
  List<OperationFinanciere> get actives =>
      ecritures.where((e) => !estNeutralisee(e)).toList();

  bool get entierementAnnule => actives.isEmpty;

  /// Ce que le versement vaut encore. Entièrement extourné, il garde son
  /// montant d'origine — affiché barré, comme une écriture annulée.
  double get total => (entierementAnnule ? ecritures : actives)
      .fold(0.0, (t, e) => t + e.montant);

  static bool estNeutralisee(OperationFinanciere e) =>
      e.estExtournee || e.statut == StatutOperation.ANNULEE;
}

/// Rassemble les écritures d'un même versement, à la place de la première.
///
/// Seule la clé [OperationFinanciere.versementId] fait foi : le serveur la
/// retire dès qu'une correction — date, chauffeur — fait que les écritures ne
/// décrivent plus le même billet. Rien n'est donc déduit ici des dates ou des
/// chauffeurs.
///
/// Un versement dont une seule écriture est à l'écran — la sœur filtrée, ou pas
/// encore chargée par la page suivante — reste une écriture seule : on ne
/// montre pas une pièce de caisse amputée d'une moitié.
List<LigneJournal> regrouperParVersement(List<OperationFinanciere> operations) {
  final parVersement = <String, List<OperationFinanciere>>{};
  for (final op in operations) {
    final id = op.versementId;
    if (id != null) parVersement.putIfAbsent(id, () => []).add(op);
  }

  final lignes = <LigneJournal>[];
  final dejaPlaces = <String>{};
  for (final op in operations) {
    final id = op.versementId;
    final membres = id == null ? null : parVersement[id];
    if (membres == null || membres.length < 2) {
      lignes.add(EcritureSeule(op));
      continue;
    }
    if (!dejaPlaces.add(id!)) continue;
    lignes.add(VersementRegroupe(List<OperationFinanciere>.unmodifiable(
        <OperationFinanciere>[...membres]..sort(_recetteDabord))));
  }
  return lignes;
}

int _rang(OperationFinanciere op) => switch (op.categorieCode?.toUpperCase()) {
      'ENCAISSEMENT_RECETTES' => 0,
      'ENCAISSEMENT_COTISATIONS' => 1,
      _ => 2,
    };

int _recetteDabord(OperationFinanciere a, OperationFinanciere b) {
  final parNature = _rang(a).compareTo(_rang(b));
  return parNature != 0 ? parNature : (a.id ?? 0).compareTo(b.id ?? 0);
}
