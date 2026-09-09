import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../domain/entities/compte_courant.dart';
import '../providers/tresorerie_providers.dart';
import 'arretes_history_page.dart' show fmtDate;

/// Formulaire d'arrêté de compte : **sélectionner les lignes** à restituer et
/// les créances à compenser, prévisualiser le décompte (fonds − créances = net),
/// puis confirmer. Toutes les lignes sont cochées par défaut → l'arrêté total
/// reste le comportement d'un simple « Restituer ».
///
/// L'écran s'ouvre sur **tout le fonds détenu**, pas sur le mois courant : c'est
/// le solde que la liste des comptes courants vient d'annoncer, et l'utilisateur
/// qui tape dessus s'attend à le retrouver. Restreindre à un mois reste possible,
/// mais c'est un geste explicite.
class ArreteFormPage extends ConsumerStatefulWidget {
  final String perimetre; // CHAUFFEUR | VEHICULE
  final int perimetreId;
  final String libelle;

  const ArreteFormPage({
    super.key,
    required this.perimetre,
    required this.perimetreId,
    required this.libelle,
  });

  @override
  ConsumerState<ArreteFormPage> createState() => _ArreteFormPageState();
}

class _ArreteFormPageState extends ConsumerState<ArreteFormPage> {
  /// Mois choisi, ou null pour « tout le fonds détenu » (l'état par défaut).
  int? _annee;
  int? _mois;
  String _mode = 'ESPECES';

  ArreteCompte? _apercu;
  bool _loading = true;
  bool _submitting = false;
  String? _erreur;

  /// Cotisations retenues (documentId de la ligne de cotisation).
  final Set<int> _cotisationsChoisies = {};

  /// Créances retenues, clé « DOCUMENT:documentId ».
  final Set<String> _creancesChoisies = {};

  static String _cleCreance(LigneArrete l) => '${l.document}:${l.documentId}';

  @override
  void initState() {
    super.initState();
    _chargerApercu();
  }

  bool get _toutLeFonds => _mois == null || _annee == null;

  /// Vrai si le document est daté avant le mois choisi. Toujours faux quand
  /// aucun mois n'est sélectionné : il n'y a alors pas de « hors période ».
  bool _avantPeriode(LigneArrete l) {
    if (_toutLeFonds || l.dateDocument == null) return false;
    return l.dateDocument!.isBefore(_debut);
  }

  /// Vrai si le document est daté après le mois choisi. Le cas est courant : le
  /// serveur rend toutes les créances ouvertes, et une recette impayée
  /// postérieure au mois filtré reste compensable. La ranger avec les
  /// antérieures faisait mentir le sous-titre de la liste.
  bool _apresPeriode(LigneArrete l) {
    if (_toutLeFonds || l.dateDocument == null) return false;
    return l.dateDocument!.isAfter(_fin);
  }

  /// Vrai si le document est daté hors du mois choisi, d'un côté ou de l'autre.
  bool _horsPeriode(LigneArrete l) => _avantPeriode(l) || _apresPeriode(l);

  /// Bornes envoyées au serveur. Sans mois choisi, on ouvre large des deux
  /// côtés : le serveur resserre ensuite la période enregistrée sur les
  /// cotisations réellement restituées, l'historique reste donc lisible.
  ///
  /// La borne haute va au-delà d'aujourd'hui à dessein : la liste des comptes
  /// courants ne borne rien, et s'arrêter à la date du jour ferait manquer à cet
  /// écran une cotisation générée d'avance — le solde annoncé sur la ligne
  /// qu'on vient de taper ne s'y retrouverait plus.
  DateTime get _debut =>
      _toutLeFonds ? DateTime(2000, 1, 1) : DateTime(_annee!, _mois!, 1);
  DateTime get _fin =>
      _toutLeFonds ? DateTime(2100, 12, 31) : DateTime(_annee!, _mois! + 1, 0);

  Future<void> _chargerApercu() async {
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      final apercu = await ref.read(tresorerieDatasourceProvider).getApercuArrete(
            perimetre: widget.perimetre,
            perimetreId: widget.perimetreId,
            debut: _debut,
            fin: _fin,
          );
      if (mounted) {
        setState(() {
          _apercu = apercu;
          _toutSelectionner(apercu);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toutSelectionner(ArreteCompte apercu) {
    _cotisationsChoisies
      ..clear()
      ..addAll(apercu.lignes.where((l) => l.estCredit).map((l) => l.documentId));
    _creancesChoisies
      ..clear()
      ..addAll(apercu.lignes.where((l) => !l.estCredit).map(_cleCreance));
  }

  void _toutCocher() {
    final apercu = _apercu;
    if (apercu != null) setState(() => _toutSelectionner(apercu));
  }

  void _toutDecocher() => setState(() {
        _cotisationsChoisies.clear();
        _creancesChoisies.clear();
      });

  // ── Décompte local (le serveur reste l'autorité) ────────────────────────────

  /// Groupe les lignes de l'aperçu par bénéficiaire chauffeur.
  List<_GroupeBeneficiaire> get _groupes {
    final apercu = _apercu;
    if (apercu == null) return const [];
    final noms = {for (final r in apercu.reglements) r.chauffeurId: r.chauffeurNom};
    final parChauffeur = <int, _GroupeBeneficiaire>{};
    for (final l in apercu.lignes) {
      final id = l.chauffeurId ?? -1;
      final g = parChauffeur.putIfAbsent(
          id, () => _GroupeBeneficiaire(id, noms[id] ?? 'Chauffeur #$id'));
      (l.estCredit ? g.cotisations : g.creances).add(l);
    }
    return parChauffeur.values.toList();
  }

  bool _cotChoisie(LigneArrete l) => _cotisationsChoisies.contains(l.documentId);
  bool _creChoisie(LigneArrete l) => _creancesChoisies.contains(_cleCreance(l));

  double _fondsGroupe(_GroupeBeneficiaire g) =>
      g.cotisations.where(_cotChoisie).fold(0.0, (s, l) => s + l.montant);

  /// La plus ancienne dette d'abord ; l'identifiant départage deux documents du
  /// même jour, pour que l'écran impute dans le même ordre que le serveur.
  static int _parAnteriorite(LigneArrete a, LigneArrete b) {
    final da = a.dateDocument;
    final db = b.dateDocument;
    if (da == null && db == null) return a.documentId.compareTo(b.documentId);
    if (da == null) return 1;
    if (db == null) return -1;
    final parJour = da.compareTo(db);
    return parJour != 0 ? parJour : a.documentId.compareTo(b.documentId);
  }

  /// Refait localement l'allocation du serveur, pour que cocher une case
  /// réponde tout de suite. Le serveur reste l'autorité : ce calcul ne décide
  /// de rien, il annonce.
  ///
  /// Deux temps, comme lui : chacun éteint d'abord ses propres créances, puis —
  /// sur un arrêté par véhicule seulement — ce qui lui reste passe aux dettes
  /// des autres chauffeurs du véhicule, par antériorité. Reproduire un simple
  /// min(fonds, créances) par chauffeur afficherait un net que l'arrêté ne
  /// verserait pas.
  _Decompte _calculer() {
    final groupes = _groupes;
    final fonds = <int, double>{};
    final dispo = <int, double>{};
    final compense = <int, double>{};
    final pourAutrui = <int, double>{};
    final reste = <String, double>{};
    for (final g in groupes) {
      fonds[g.chauffeurId] = _fondsGroupe(g);
      dispo[g.chauffeurId] = fonds[g.chauffeurId]!;
      compense[g.chauffeurId] = 0;
      pourAutrui[g.chauffeurId] = 0;
      for (final l in g.creances) {
        reste[_cleCreance(l)] = l.du;
      }
    }

    void imputer(_GroupeBeneficiaire g, List<LigneArrete> creances) {
      for (final l in creances) {
        if (dispo[g.chauffeurId]! <= 0) return;
        if (!_creChoisie(l)) continue;
        final cle = _cleCreance(l);
        final du = reste[cle] ?? 0;
        if (du <= 0) continue;
        final part = math.min(dispo[g.chauffeurId]!, du);
        dispo[g.chauffeurId] = dispo[g.chauffeurId]! - part;
        compense[g.chauffeurId] = compense[g.chauffeurId]! + part;
        if (l.chauffeurId != g.chauffeurId) {
          pourAutrui[g.chauffeurId] = pourAutrui[g.chauffeurId]! + part;
        }
        reste[cle] = du - part;
      }
    }

    for (final g in groupes) {
      imputer(g, g.creances);
    }
    if (widget.perimetre == 'VEHICULE') {
      final duVehicule = [for (final g in groupes) ...g.creances]
        ..sort(_parAnteriorite);
      for (final g in groupes) {
        imputer(g, duVehicule);
      }
    }

    return _Decompte(groupes, fonds, dispo, compense, pourAutrui, reste);
  }

  bool get _peutValider => _cotisationsChoisies.isNotEmpty;

  /// Vrai quand l'écran ne montre que des créances : rien à restituer, et le
  /// bouton doit le dire plutôt que réclamer une sélection impossible.
  bool get _aucuneCotisation =>
      _apercu != null && _apercu!.lignes.every((l) => !l.estCredit);

  void basculeCotisation(int documentId, bool? coche) => setState(() {
        if (coche == true) {
          _cotisationsChoisies.add(documentId);
        } else {
          _cotisationsChoisies.remove(documentId);
        }
      });

  void basculeCreance(LigneArrete l, bool? coche) => setState(() {
        final cle = _cleCreance(l);
        if (coche == true) {
          _creancesChoisies.add(cle);
        } else {
          _creancesChoisies.remove(cle);
        }
      });

  Future<void> _confirmer() async {
    setState(() => _submitting = true);
    try {
      final creances = _apercu!.lignes
          .where((l) => !l.estCredit && _creChoisie(l))
          .map((l) => {'document': l.document, 'documentId': l.documentId})
          .toList();
      // Le compte à débiter se déduit du mode : espèces → la caisse, mobile
      // money → le portefeuille. C'est le serveur qui le résout, sur les
      // comptes marqués par défaut ; l'écran n'a rien à désigner.
      await ref.read(tresorerieDatasourceProvider).arreter(
            perimetre: widget.perimetre,
            perimetreId: widget.perimetreId,
            periodeDebut: _debut,
            periodeFin: _fin,
            modePaiement: _mode,
            cotisationIds: _cotisationsChoisies.toList(),
            creances: creances,
          );
      // L'arrêté touche les créances, les cotisations et une caisse : tout ce
      // qui en dérive est périmé. Les familles sont invalidées sans argument —
      // n'en rafraîchir qu'un axe laisserait l'autre afficher l'avant.
      ref.invalidate(arretesProvider);
      ref.invalidate(comptesCourantsProvider);
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(balanceAgeeVehiculeProvider);
      ref.invalidate(creancesChauffeurProvider);
      ref.invalidate(creancesVehiculeProvider);
      ref.invalidate(releveChauffeurProvider);
      ref.invalidate(tresorerieSummaryProvider);
      ref.invalidate(bilanProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Arrêté enregistré')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Arrêté refusé : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apercu = _apercu;
    final rien = apercu == null || apercu.lignes.isEmpty;
    final decompte = _calculer();

    return Scaffold(
      appBar: AppHeader(title: 'Arrêté — ${widget.libelle}'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Text('Fonds à restituer',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label)),
          const SizedBox(height: 2),
          // Le filtre porte sur le jour que la cotisation couvre, pas sur celui
          // où le chauffeur l'a payée : une cotisation de juillet réglée en août
          // se trouve sous juillet. Sans ce rappel, l'écart avec la caisse du
          // mois passe pour une erreur de calcul.
          const Text('Mois de la cotisation, pas du versement',
              style: TextStyle(fontSize: 11, color: AppColors.hint)),
          const SizedBox(height: 6),
          MonthFilterPill(
            mois: _mois,
            annee: _annee,
            libelleVide: 'Tout le fonds détenu',
            onChanged: (m, a) {
              setState(() {
                _mois = m;
                _annee = a;
              });
              _chargerApercu();
            },
            // La croix ramène au fonds entier — l'état où ce que montre l'écran
            // correspond au solde annoncé par la liste des comptes courants.
            onEfface: () {
              setState(() {
                _mois = null;
                _annee = null;
              });
              _chargerApercu();
            },
          ),
          if (!_toutLeFonds) ...[
            const SizedBox(height: 6),
            // Le mois ne borne que le fonds : côté créances, le serveur rend
            // tout ce qui est ouvert, parce qu'un dépôt doit pouvoir éteindre
            // une dette plus ancienne que lui. Le taire laissait croire que le
            // total des créances était celui du mois.
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.headerButton,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: AppColors.label),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'Le mois ne filtre que le fonds. Toutes les créances '
                        'ouvertes restent compensables, antérieures comme '
                        'postérieures.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.label, height: 1.3)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()))
          else if (_erreur != null)
            _MessageCard('Impossible de calculer le décompte : $_erreur',
                Colors.red.shade900, const Color(0xFFFDECEA))
          else if (rien)
            const _MessageCard(
                'Aucune cotisation ni créance sur cette période.',
                AppColors.label,
                AppColors.headerButton)
          else ...[
            _SyntheseCard(
              fonds: decompte.totalFonds,
              compense: decompte.totalCompense,
              net: decompte.totalNet,
              reliquat: decompte.totalReliquat,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Expanded(
                  child: Text('Lignes à restituer / compenser',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.label)),
                ),
                TextButton(
                    onPressed: _toutCocher,
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Tout', style: TextStyle(fontSize: 12.5))),
                TextButton(
                    onPressed: _toutDecocher,
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Rien', style: TextStyle(fontSize: 12.5))),
              ],
            ),
            const SizedBox(height: 4),
            for (final g in decompte.groupes)
              _GroupeCard(groupe: g, etat: this, decompte: decompte),
            const SizedBox(height: 8),
            if (decompte.totalNet > 0) ...[
              const Text('Mode de versement',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label)),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ESPECES', label: Text('Espèces')),
                  ButtonSegment(value: 'MOBILE_MONEY', label: Text('Mobile Money')),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ],
          ],
        ],
      ),
      bottomNavigationBar: rien
          ? null
          : Padding(
              // La fenêtre est en edge-to-edge : la barre de navigation Android
              // (gestes ou trois boutons) se dessine par-dessus le bas de
              // l'écran et recouvrait le bouton. On lit viewPadding plutôt que
              // de compter sur SafeArea, qui s'appuie sur `padding` — ramené à
              // zéro dès qu'un clavier s'ouvre ou qu'un ancêtre l'a consommé.
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 16 + MediaQuery.viewPaddingOf(context).bottom),
              child: FilledButton.icon(
                onPressed:
                    _submitting || _loading || !_peutValider ? null : _confirmer,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_rounded),
                label: Text(!_peutValider
                    ? (_aucuneCotisation
                        ? 'Aucune cotisation à restituer'
                        : 'Sélectionnez au moins une cotisation')
                    : decompte.totalNet > 0
                        ? 'Restituer ${CurrencyFormatter.format(decompte.totalNet)}'
                        : 'Compenser (aucun versement)'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              ),
            ),
    );
  }
}

/// Décompte local d'un arrêté : ce que chaque fonds éteint, ce qu'il reste sur
/// chaque créance, et les totaux de l'écran. Recalculé d'un bloc à chaque build
/// par [_ArreteFormPageState._calculer] — la liste est courte, et c'est ce qui
/// rend les cases à cocher instantanées.
class _Decompte {
  final List<_GroupeBeneficiaire> groupes;
  final Map<int, double> _fonds;
  /// Fonds encore disponible après imputation : c'est le net à verser.
  final Map<int, double> _net;
  /// Ce que son fonds a éteint, chez lui comme chez les autres.
  final Map<int, double> _compense;
  final Map<int, double> _pourAutrui;
  /// Ce qu'il reste dû sur chaque créance, tous financeurs confondus.
  final Map<String, double> _reste;

  const _Decompte(this.groupes, this._fonds, this._net, this._compense,
      this._pourAutrui, this._reste);

  double fonds(_GroupeBeneficiaire g) => _fonds[g.chauffeurId] ?? 0;
  double net(_GroupeBeneficiaire g) => _net[g.chauffeurId] ?? 0;
  double compense(_GroupeBeneficiaire g) => _compense[g.chauffeurId] ?? 0;

  /// Ce que le fonds de ce chauffeur a mis sur les dettes des AUTRES. Toujours
  /// nul hors arrêté par véhicule — c'est là que les fonds se mutualisent.
  double pourAutrui(_GroupeBeneficiaire g) => _pourAutrui[g.chauffeurId] ?? 0;

  /// Ce qui reste dû sur SES créances après l'arrêté, d'où que vienne l'argent
  /// qui les a entamées : une dette soldée par le chauffeur d'à côté n'est plus
  /// un reliquat pour celui qui la portait.
  double reliquat(_GroupeBeneficiaire g) => g.creances.fold(
      0.0, (s, l) => s + (_reste[_ArreteFormPageState._cleCreance(l)] ?? 0));

  double get totalFonds => groupes.fold(0.0, (s, g) => s + fonds(g));
  double get totalCompense => groupes.fold(0.0, (s, g) => s + compense(g));
  double get totalNet => groupes.fold(0.0, (s, g) => s + net(g));
  double get totalReliquat => groupes.fold(0.0, (s, g) => s + reliquat(g));
}

/// Un bénéficiaire chauffeur : ses cotisations (crédit) et créances (débit).
class _GroupeBeneficiaire {
  final int chauffeurId;
  final String nom;
  final List<LigneArrete> cotisations = [];
  final List<LigneArrete> creances = [];
  _GroupeBeneficiaire(this.chauffeurId, this.nom);
}

class _SyntheseCard extends StatelessWidget {
  final double fonds;
  final double compense;
  final double net;

  /// Ce que le fonds ne couvre pas et qui restera dû après l'arrêté, sur
  /// l'ensemble des créances ouvertes — décocher une ligne ne l'en retire pas.
  /// Affiché dès qu'il est non nul : valider en ignorant ce qui reste à la
  /// charge du chauffeur est précisément ce qu'il faut éviter.
  final double reliquat;
  const _SyntheseCard(
      {required this.fonds,
      required this.compense,
      required this.net,
      required this.reliquat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Column(
        children: [
          _ligne('Fonds sélectionné', fonds, AppColors.dark),
          const Divider(height: 18),
          _ligne('− Créances compensées', compense, Colors.orange.shade900),
          if (reliquat > 0)
            _ligne('Reste dû après arrêté', reliquat, Colors.red.shade900,
                aide: 'toutes créances ouvertes'),
          const Divider(height: 18),
          _ligne('= Net à restituer', net, Colors.green.shade800, gras: true),
        ],
      ),
    );
  }

  Widget _ligne(String label, double montant, Color couleur,
      {bool gras = false, String? aide}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: gras ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.dark)),
              if (aide != null)
                Text(aide,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.hint)),
            ],
          ),
          Text(CurrencyFormatter.format(montant),
              style: TextStyle(
                  fontSize: gras ? 15 : 13,
                  fontWeight: gras ? FontWeight.w700 : FontWeight.w600,
                  color: couleur)),
        ],
      ),
    );
  }
}

/// Carte d'un bénéficiaire : cases à cocher des cotisations puis des créances,
/// et le net résultant pour ce chauffeur.
class _GroupeCard extends StatelessWidget {
  final _GroupeBeneficiaire groupe;
  final _ArreteFormPageState etat;
  final _Decompte decompte;
  const _GroupeCard(
      {required this.groupe, required this.etat, required this.decompte});

  static const _libellesDoc = {
    'RECETTE': 'Recette',
    'PENALITE': 'Pénalité',
    'CONTRAVENTION': 'Contravention',
  };

  /// Ce qui distingue deux lignes du même type pour l'utilisateur : le jour que
  /// le document couvre. L'identifiant ne sert plus que de repli, quand le
  /// serveur n'a pas su résoudre la date.
  static String _repere(LigneArrete l) =>
      l.dateDocument != null ? fmtDate(l.dateDocument) : '#${l.documentId}';

  @override
  Widget build(BuildContext context) {
    final net = decompte.net(groupe);
    // Ce que son dépôt a mis sur les dettes des autres chauffeurs du véhicule.
    // Sans ce rappel, son net baisse sans que rien à l'écran ne dise pourquoi.
    final pourAutrui = decompte.pourAutrui(groupe);
    final anterieures = groupe.creances.where(etat._avantPeriode).toList();
    final posterieures = groupe.creances.where(etat._apresPeriode).toList();
    final dansPeriode =
        groupe.creances.where((l) => !etat._horsPeriode(l)).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(groupe.nom,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dark)),
                ),
                Text('Net ${CurrencyFormatter.format(net)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: net > 0
                            ? Colors.green.shade800
                            : AppColors.hint)),
              ],
            ),
          ),
          if (pourAutrui > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
              child: Text(
                  'dont ${CurrencyFormatter.format(pourAutrui)} pour les dettes '
                  'des autres chauffeurs du véhicule',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
            ),
          if (groupe.cotisations.isNotEmpty)
            _sousTitre('Cotisations (fonds)'),
          for (final l in groupe.cotisations)
            _tuile(
              context,
              titre: 'Cotisation',
              sousTitre: _repere(l),
              montant: l.montant,
              couleurMontant: AppColors.dark,
              coche: etat._cotChoisie(l),
              onChanged: (v) => etat.basculeCotisation(l.documentId, v),
            ),
          // Le serveur rend toutes les créances ouvertes, mois filtré ou non.
          // Les séparer est ce qui permet de voir d'un coup d'œil ce que le
          // fonds du mois s'apprête à éteindre en dehors de ce mois — l'ordre
          // de compensation, lui, reste celui du serveur (par antériorité).
          if (dansPeriode.isNotEmpty)
            _sousTitre(etat._toutLeFonds
                ? 'Créances à compenser'
                : 'Créances du mois'),
          for (final l in dansPeriode) _tuileCreance(context, l),
          if (anterieures.isNotEmpty) _sousTitre('Créances antérieures'),
          for (final l in anterieures) _tuileCreance(context, l),
          if (posterieures.isNotEmpty) _sousTitre('Créances postérieures'),
          for (final l in posterieures) _tuileCreance(context, l),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  /// Une créance telle qu'elle est due : ce que le document réclamait, et ce
  /// qu'il en reste aujourd'hui. La part que cet arrêté en éteint ne figure pas
  /// ici — elle se lisait comme le montant de la créance et faisait passer une
  /// recette attendue de 21 000 pour une recette de 15 000. Le décompte de la
  /// compensation est en haut de l'écran, où il porte sur l'ensemble.
  ///
  /// La liste ne contient que des créances ouvertes : le serveur ne rend ni les
  /// documents annulés ni ceux qu'un arrêté a soldés.
  Widget _tuileCreance(BuildContext context, LigneArrete l) => _tuile(
        context,
        titre: _libellesDoc[l.document] ?? l.document,
        sousTitre: _repere(l),
        montant: l.origine,
        note: 'reste ${CurrencyFormatter.format(l.du)}',
        couleurNote: Colors.red.shade900,
        couleurMontant: Colors.orange.shade900,
        coche: etat._creChoisie(l),
        onChanged: (v) => etat.basculeCreance(l, v),
      );

  Widget _sousTitre(String texte) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        child: Text(texte,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.hint)),
      );

  Widget _tuile(
    BuildContext context, {
    required String titre,
    required String sousTitre,
    required double montant,
    required Color couleurMontant,
    required bool coche,
    required ValueChanged<bool?> onChanged,
    String? note,
    Color? couleurNote,
  }) {
    return InkWell(
      onTap: () => onChanged(!coche),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          children: [
            Checkbox(
              value: coche,
              onChanged: onChanged,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$titre  $sousTitre',
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.dark)),
                  if (note != null)
                    Text(note,
                        style: TextStyle(
                            fontSize: 11,
                            color: couleurNote ?? AppColors.hint)),
                ],
              ),
            ),
            Text(CurrencyFormatter.format(montant),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: couleurMontant)),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final Color fg;
  final Color bg;
  const _MessageCard(this.message, this.fg, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(message, style: TextStyle(fontSize: 13, color: fg)),
    );
  }
}
