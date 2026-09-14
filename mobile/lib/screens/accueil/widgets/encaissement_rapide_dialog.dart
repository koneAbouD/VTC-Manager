import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/montant_field.dart';
import '../../../features/vehicule/domain/entities/vehicule.dart';
import '../../../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../../../features/vehicule/presentation/providers/vehicule_state.dart';
import '../../../features/cotisation/domain/entities/ligne_cotisation.dart';
import '../../../features/cotisation/domain/entities/ligne_cotisation_filtres.dart';
import '../../../features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import '../../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../../features/recette/domain/entities/ligne_recette.dart';
import '../../../features/recette/presentation/providers/ligne_recette_provider.dart';
import '../../../features/operation_financiere/domain/enums/mode_paiement.dart';
import '../../../features/versement/domain/entities/encaissement_versement.dart';
import '../../../features/versement/presentation/providers/versement_provider.dart';

// ── Palette (cohérente avec MaintenanceFormPage) ──────────────────────────────

const _kPrimary   = Color(0xFF3B5BDB);
const _kGreen     = Color(0xFF2E7D32);
const _kOrange    = Color(0xFFE65100);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint      = Color(0xFF9AA0AE);
const _kLabel     = Color(0xFF6B7280);
const _kBorder    = Color(0xFFE3E6EE);
const _kDark      = Color(0xFF1A1A2E);
const _kError     = Color(0xFFE03131);

// ── Entrée du bottom sheet ────────────────────────────────────────────────────

Future<bool?> showEncaissementRapideDialog(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFFF8F9FB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _EncaissementRapideSheet(),
  );
}

// ── État de chargement des lignes ─────────────────────────────────────────────

enum _LignesStatus { idle, loading, loaded, error }

// ── Sheet principale ──────────────────────────────────────────────────────────

class _EncaissementRapideSheet extends ConsumerStatefulWidget {
  const _EncaissementRapideSheet();

  @override
  ConsumerState<_EncaissementRapideSheet> createState() =>
      _EncaissementRapideSheetState();
}

class _EncaissementRapideSheetState
    extends ConsumerState<_EncaissementRapideSheet> {
  // ── Véhicule ───────────────────────────────────────────────────────────────
  Vehicule? _vehicule;

  // ── Lignes actives chargées après sélection ────────────────────────────────
  _LignesStatus _lignesStatus = _LignesStatus.idle;
  LigneRecette? _ligneRecette;
  LigneCotisation? _ligneCotisation;
  String? _lignesError;

  // ── Lignes retenues pour le versement ──────────────────────────────────────
  // Le chauffeur ne règle pas toujours les deux : les cases écartent une ligne
  // du versement. Elles pilotent le montant prérempli, et le montant saisi à la
  // main les repilote en retour (une cotisation que la saisie ne couvre plus se
  // décoche d'elle-même).
  bool _inclureRecette    = false;
  bool _inclureCotisation = false;

  // ── Formulaire ─────────────────────────────────────────────────────────────
  final _montantCtrl  = TextEditingController();
  final _commentCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _submitting   = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _montantCtrl.addListener(_onMontantChange);
    // S'assurer que la liste des véhicules est disponible pour la sélection.
    Future.microtask(
        () => ref.read(vehiculeNotifierProvider.notifier).loadVehicules());
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ── Véhicules ──────────────────────────────────────────────────────────────

  List<Vehicule> get _vehicules {
    final s = ref.watch(vehiculeNotifierProvider);
    return switch (s) {
      VehiculeLoaded(:final vehicules)       => vehicules,
      VehiculeActionSuccess(:final vehicules) => vehicules,
      _ => <Vehicule>[],
    };
  }

  // ── Montants restants ──────────────────────────────────────────────────────

  /// Restant de la recette, ou `null` s'il est inconnu (recette libre, sans
  /// montant attendu).
  static double? _restantRecette(LigneRecette? l) => l?.montantRestant;

  static double? _restantCotisation(LigneCotisation? l) => l == null
      ? null
      : (l.montantRestant ?? (l.montantDu - l.montantEncaisse));

  /// Somme des restants des lignes actives, ou `null` si aucun n'est connu.
  static double? _totalRestant(LigneRecette? r, LigneCotisation? c) {
    final rr = _restantRecette(r);
    final cc = _restantCotisation(c);
    if (rr == null && cc == null) return null;
    return (rr ?? 0) + (cc ?? 0);
  }

  double get _recetteRestant => (_ligneRecette == null || !_inclureRecette)
      ? 0
      : (_restantRecette(_ligneRecette) ?? double.maxFinite);

  double get _cotisationRestant =>
      _inclureCotisation ? (_restantCotisation(_ligneCotisation) ?? 0) : 0;

  /// Somme des restants des seules lignes cochées : plafond de la saisie et
  /// valeur du préremplissage. `null` quand aucun restant n'est connu.
  double? get _totalSelectionne => _totalRestant(
        _inclureRecette ? _ligneRecette : null,
        _inclureCotisation ? _ligneCotisation : null,
      );

  bool get _aUneLigneSelectionnee =>
      (_ligneRecette != null && _inclureRecette) ||
      (_ligneCotisation != null && _inclureCotisation);

  // ── Répartition : recette d'abord, cotisation ensuite ─────────────────────

  ({double recette, double cotisation}) get _distribution {
    final montant = parseMontant(_montantCtrl.text) ?? 0;
    if (montant <= 0) return (recette: 0, cotisation: 0);
    final recettePart     = montant.clamp(0.0, _recetteRestant);
    final cotisationPart  = (montant - recettePart).clamp(0.0, _cotisationRestant);
    return (recette: recettePart, cotisation: cotisationPart);
  }

  // ── Synchronisation cases ↔ montant ───────────────────────────────────────

  /// Réaligne le champ montant sur les lignes cochées.
  void _appliquerMontantSelection() {
    final total = _totalSelectionne;
    _montantCtrl.text =
        (total != null && total > 0) ? formatMontantSaisie(total) : '';
  }

  /// La cotisation, servie après la recette, suit ce qui reste du montant :
  /// elle se décoche dès que la saisie ne laisse rien pour elle, et se recoche
  /// dès que la saisie repasse au-dessus de la recette. La recette, elle, garde
  /// le choix de l'utilisateur : la décocher est une façon de ne régler que la
  /// cotisation, et le montant est alors plafonné à celle-ci.
  void _synchroniserCotisation() {
    if (_ligneCotisation == null) return;

    final montant = parseMontant(_montantCtrl.text) ?? 0;
    // Champ vidé : on laisse les cases en l'état plutôt que de tout décocher
    // sous les doigts de l'utilisateur en train d'effacer.
    if (montant <= 0) return;

    final restantRecette =
        _inclureRecette ? _restantRecette(_ligneRecette) : 0.0;
    // Recette sans montant attendu : elle absorbe tout, la part de la
    // cotisation n'est pas calculable — on ne touche pas aux cases.
    if (_ligneRecette != null && _inclureRecette && restantRecette == null) {
      return;
    }

    _inclureCotisation = montant > (restantRecette ?? 0);
  }

  void _onMontantChange() {
    _synchroniserCotisation();
    if (mounted) setState(() {});
  }

  void _basculerRecette(bool? valeur) {
    setState(() => _inclureRecette = valeur ?? false);
    _appliquerMontantSelection();
  }

  void _basculerCotisation(bool? valeur) {
    setState(() => _inclureCotisation = valeur ?? false);
    _appliquerMontantSelection();
  }

  // ── Chargement des lignes après sélection du véhicule ─────────────────────

  Future<void> _chargerLignes(Vehicule v) async {
    // Hors setState : vider le champ notifie déjà le listener, qui reconstruit.
    _montantCtrl.clear();
    setState(() {
      _vehicule     = v;
      _lignesStatus = _LignesStatus.loading;
      _ligneRecette = null;
      _ligneCotisation = null;
      _inclureRecette    = false;
      _inclureCotisation = false;
      _lignesError  = null;
    });

    final recetteRepo    = ref.read(ligneRecetteRepositoryProvider);
    final cotisationRepo = ref.read(ligneCotisationRepositoryProvider);

    final recetteResult    = await recetteRepo.getLignes(vehiculeId: v.id!);
    final cotisationResult = await cotisationRepo
        .getLignes(LigneCotisationFiltres(vehiculeId: v.id!));

    if (!mounted) return;

    LigneRecette?    ligneR;
    LigneCotisation? ligneC;
    String?          err;

    recetteResult.fold(
      (f) => err = f.message,
      (lignes) {
        final actives = lignes.where((l) => l.estActive).toList();
        if (actives.isNotEmpty) ligneR = actives.first;
      },
    );

    if (err == null) {
      cotisationResult.fold(
        (f) => err = f.message,
        (lignes) {
          final actives = lignes.where((l) => l.estActive).toList();
          if (actives.isNotEmpty) ligneC = actives.first;
        },
      );
    }

    if (err == null && ligneR == null && ligneC == null) {
      err = 'Aucune ligne active (recette ou cotisation) pour ce véhicule';
    }

    setState(() {
      _lignesStatus    = err != null ? _LignesStatus.error : _LignesStatus.loaded;
      _ligneRecette    = ligneR;
      _ligneCotisation = ligneC;
      _lignesError     = err;
      // Toutes les lignes trouvées sont retenues par défaut.
      _inclureRecette    = err == null && ligneR != null;
      _inclureCotisation = err == null && ligneC != null;
    });

    // Préremplissage : total restant des lignes cochées.
    _appliquerMontantSelection();
  }

  // ── Soumission ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final dist = _distribution;
    // Filet : rien de coché, ou un montant qu'aucune ligne retenue n'absorbe.
    if (dist.recette <= 0 && dist.cotisation <= 0) {
      setState(() => _submitError =
          'Aucun montant à encaisser sur les lignes sélectionnées');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final commentaire = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();
    // Un billet, un appel : la recette et la cotisation du jour passent
    // ensemble ou pas du tout, rattachées à la même pièce de caisse.
    final resultat = await ref.read(versementRepositoryProvider).encaisser(
          recette: dist.recette > 0 && _ligneRecette != null
              ? PartVersement(ligneId: _ligneRecette!.id!, montant: dist.recette)
              : null,
          cotisation: dist.cotisation > 0 && _ligneCotisation != null
              ? PartVersement(
                  ligneId: _ligneCotisation!.id!, montant: dist.cotisation)
              : null,
          mode: ModePaiement.ESPECES,
          date: DateTime.now(),
          commentaire: commentaire,
        );
    final error = resultat.fold((f) => f.message, (_) => null);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      // L'erreur est affichée dans la feuille (bandeau inline) plutôt qu'en
      // SnackBar : la feuille reste ouverte, donc un SnackBar flottant
      // s'afficherait masqué sous le bottom sheet.
      _submitError = error;
    });

    if (error != null) return;

    ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
    Navigator.pop(context, true);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fmt  = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    // useSafeArea applique SafeArea(bottom: false) : la barre de navigation
    // système d'Android n'est pas protégée. On ajoute donc son inset au bas
    // pour que le bouton « Encaisser » ne passe pas sous la barre latérale.
    final bottomSafe     = MediaQuery.paddingOf(context).bottom;
    final dist           = _distribution;

    final lignesOk       = _lignesStatus == _LignesStatus.loaded;
    final lignesLoading  = _lignesStatus == _LignesStatus.loading;
    final lignesError    = _lignesStatus == _LignesStatus.error;

    final totalRestantConnu = _totalSelectionne;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight + bottomSafe),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Indicateur de glissement ──────────────────────────────────
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Titre ─────────────────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Encaissement rapide',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _kDark,
                    letterSpacing: -0.4),
              ),
            ),

            // ── Section : Véhicule ────────────────────────────────────────
            _FormCard(
              icon:   Icons.directions_car_outlined,
              accent: _kGreen,
              title:  'Véhicule',
              child: _LabeledField(
                label:      'Véhicule',
                isRequired: true,
                child: Autocomplete<Vehicule>(
                  displayStringForOption: (v) => v.immatriculation,
                  optionsBuilder: (value) {
                    final q = value.text.toLowerCase();
                    if (q.isEmpty) return _vehicules;
                    return _vehicules.where((v) =>
                        v.immatriculation.toLowerCase().contains(q) ||
                        v.displayName.toLowerCase().contains(q));
                  },
                  onSelected: _chargerLignes,
                  fieldViewBuilder: (ctx, ctrl, focus, onSubmit) =>
                      TextFormField(
                    controller: ctrl,
                    focusNode:  focus,
                    onFieldSubmitted: (_) => onSubmit(),
                    style: const TextStyle(fontSize: 15, color: _kDark),
                    decoration: _fieldDeco('Rechercher un véhicule…').copyWith(
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: _kHint),
                      suffixIcon: lignesLoading
                          ? const Padding(
                              padding: EdgeInsets.all(13),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _kPrimary),
                              ),
                            )
                          : _vehicule != null && lignesOk
                              ? const Icon(Icons.check_circle_outline_rounded,
                                  size: 18, color: _kGreen)
                              : null,
                    ),
                    validator: (_) => _vehicule == null
                        ? 'Veuillez sélectionner un véhicule'
                        : null,
                  ),
                  optionsViewBuilder: (ctx, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 6,
                      shadowColor: Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 210),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          shrinkWrap: true,
                          itemCount: options.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: Colors.grey.shade100),
                          itemBuilder: (_, i) {
                            final v = options.elementAt(i);
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 17,
                                backgroundColor:
                                    _kPrimary.withValues(alpha: 0.10),
                                child: const Icon(
                                    Icons.directions_car_outlined,
                                    color: _kPrimary,
                                    size: 17),
                              ),
                              title: Text(v.immatriculation,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: _kDark)),
                              subtitle: Text(v.displayName,
                                  style: const TextStyle(
                                      fontSize: 11, color: _kHint)),
                              onTap: () => onSelected(v),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Section : Lignes actives ──────────────────────────────────
            if (lignesOk) ...[
              _LignesCard(
                ligneRecette:      _ligneRecette,
                ligneCotisation:   _ligneCotisation,
                inclureRecette:    _inclureRecette,
                inclureCotisation: _inclureCotisation,
                onRecetteChanged:    _basculerRecette,
                onCotisationChanged: _basculerCotisation,
                fmt:               fmt,
              ),
              if (!_aUneLigneSelectionnee) ...[
                const _InlineAlert(
                  message: 'Cochez au moins une ligne à encaisser',
                  isError: false,
                ),
                const SizedBox(height: 8),
              ],
            ],

            if (lignesError && _lignesError != null)
              _InlineAlert(message: _lignesError!, isError: true),

            // ── Section : Encaissement ────────────────────────────────────
            if (lignesOk) ...[
              _FormCard(
                icon:   Icons.payments_outlined,
                accent: _kGreen,
                title:  'Encaissement',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Montant
                    _LabeledField(
                      label:      'Montant',
                      isRequired: true,
                      child: MontantField(
                        controller: _montantCtrl,
                        // Le versement ne peut couvrir que ce qui est coché :
                        // la recette du jour, la cotisation, ou les deux.
                        plafond:        totalRestantConnu,
                        libellePlafond: 'le total restant',
                        style: const TextStyle(fontSize: 15, color: _kDark),
                        decoration: _fieldDeco('0').copyWith(
                          suffixText: 'XOF',
                          suffixStyle: const TextStyle(
                              color: _kLabel,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),

                    // Répartition en temps réel
                    if (dist.recette > 0 || dist.cotisation > 0) ...[
                      const SizedBox(height: 10),
                      _RepartitionCard(
                        recette: (_ligneRecette != null && _inclureRecette)
                            ? dist.recette
                            : null,
                        cotisation:
                            (_ligneCotisation != null && _inclureCotisation)
                                ? dist.cotisation
                                : null,
                        fmt: fmt,
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Commentaire
                    _LabeledField(
                      label: 'Commentaire',
                      child: TextFormField(
                        controller: _commentCtrl,
                        maxLines:   2,
                        style: const TextStyle(fontSize: 15, color: _kDark),
                        decoration: _fieldDeco('Remarques éventuelles…'),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 4),

            // ── Erreur de soumission (ex. mode de paiement non autorisé) ──
            if (_submitError != null) ...[
              _InlineAlert(message: _submitError!, isError: true),
              const SizedBox(height: 8),
            ],

            // ── Bouton ────────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: (_submitting ||
                        lignesLoading ||
                        !lignesOk ||
                        !_aUneLigneSelectionnee)
                    ? null
                    : _submit,
                icon: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _submitting ? 'Encaissement en cours…' : 'Encaisser',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ── Card lignes actives ───────────────────────────────────────────────────────

class _LignesCard extends StatelessWidget {
  final LigneRecette?    ligneRecette;
  final LigneCotisation? ligneCotisation;

  /// Lignes retenues pour le versement : la case de chacune.
  final bool inclureRecette;
  final bool inclureCotisation;
  final ValueChanged<bool?> onRecetteChanged;
  final ValueChanged<bool?> onCotisationChanged;

  final NumberFormat     fmt;

  const _LignesCard({
    required this.ligneRecette,
    required this.ligneCotisation,
    required this.inclureRecette,
    required this.inclureCotisation,
    required this.onRecetteChanged,
    required this.onCotisationChanged,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Deux lignes actives peuvent porter des jours différents : une recette
    // d'hier encore ouverte face à la cotisation du jour. Chaque badge affiche
    // donc sa propre date.
    final jourFmt = DateFormat('EEE dd/MM/yyyy', 'fr_FR');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_outlined,
                  size: 18, color: _kPrimary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Lignes actives trouvées',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kDark,
                          letterSpacing: -0.2)),
                  SizedBox(height: 2),
                  Text('Décochez une ligne pour la retirer du versement',
                      style: TextStyle(fontSize: 11, color: _kHint)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // Recette
          if (ligneRecette != null)
            _LigneBadge(
              icon:    Icons.account_balance_wallet_outlined,
              label:   'Recette',
              jour:    jourFmt.format(ligneRecette!.dateRecette),
              montant: ligneRecette!.montantRestant != null
                  ? fmt.format(ligneRecette!.montantRestant!)
                  : '—',
              color:   _kGreen,
              selectionne: inclureRecette,
              onChanged:   onRecetteChanged,
            ),

          if (ligneRecette != null && ligneCotisation != null)
            Divider(height: 16, color: Colors.grey.shade100),

          // Cotisation
          if (ligneCotisation != null)
            _LigneBadge(
              icon:    Icons.analytics_outlined,
              label:   ligneCotisation!.nomCotisation,
              jour:    jourFmt.format(ligneCotisation!.dateCotisation),
              montant: fmt.format(
                ligneCotisation!.montantRestant ??
                    (ligneCotisation!.montantDu -
                        ligneCotisation!.montantEncaisse),
              ),
              color:   _kOrange,
              selectionne: inclureCotisation,
              onChanged:   onCotisationChanged,
            ),
        ],
      ),
    );
  }
}

class _LigneBadge extends StatelessWidget {
  final IconData icon;
  final String   label;

  /// Jour rattaché à la ligne, déjà formaté (« lun. 01/09/2026 »).
  final String   jour;
  final String   montant;
  final Color    color;

  /// Ligne retenue pour le versement. Décochée, elle reste affichée mais
  /// grisée : elle ne reçoit rien et ne compte plus dans le montant.
  final bool                selectionne;
  final ValueChanged<bool?> onChanged;

  const _LigneBadge({
    required this.icon,
    required this.label,
    required this.jour,
    required this.montant,
    required this.color,
    required this.selectionne,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Ligne écartée : tout passe en gris, le montant restant n'entre plus dans
    // le versement.
    final teinte = selectionne ? color : _kHint;

    return InkWell(
      onTap: () => onChanged(!selectionne),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: selectionne,
              onChanged: onChanged,
              activeColor: color,
              side: const BorderSide(color: _kHint, width: 1.6),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5)),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: teinte.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: teinte),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: selectionne ? _kDark : _kHint)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.event_outlined, size: 11, color: _kHint),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(jour,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _kHint)),
                  ),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: teinte.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Restant : $montant',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: teinte),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Card répartition ──────────────────────────────────────────────────────────

class _RepartitionCard extends StatelessWidget {
  final double?      recette;
  final double?      cotisation;
  final NumberFormat fmt;

  const _RepartitionCard({
    required this.recette,
    required this.cotisation,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kGreen.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kGreen.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.alt_route_outlined, size: 13, color: _kGreen),
            const SizedBox(width: 5),
            Text('Répartition du montant',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _kGreen.withValues(alpha: 0.85),
                    letterSpacing: 0.2)),
          ]),
          const SizedBox(height: 8),
          if (recette != null && recette! > 0) ...[
            _RepartitionRow(
              icon:  Icons.account_balance_wallet_outlined,
              label: 'Recette',
              value: fmt.format(recette!),
              color: _kGreen,
            ),
          ],
          if (recette != null && recette! > 0 &&
              cotisation != null && cotisation! > 0)
            const SizedBox(height: 5),
          if (cotisation != null && cotisation! > 0)
            _RepartitionRow(
              icon:  Icons.analytics_outlined,
              label: 'Cotisation',
              value: fmt.format(cotisation!),
              color: _kOrange,
            ),
        ],
      ),
    );
  }
}

class _RepartitionRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _RepartitionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(fontSize: 12, color: _kLabel)),
      const Spacer(),
      Text(value,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

// ── Bannière d'alerte inline ──────────────────────────────────────────────────

class _InlineAlert extends StatelessWidget {
  final String message;
  final bool   isError;

  const _InlineAlert({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final bg     = isError
        ? const Color(0xFFFFF0F0)
        : const Color(0xFFFFF8EC);
    final border = isError
        ? const Color(0xFFFFCDD2)
        : const Color(0xFFFFE0B2);
    final text   = isError ? _kError : _kOrange;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.warning_amber_rounded,
            color: text,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 13,
                    color: text,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Widgets partagés (réplique du style de MaintenanceFormPage) ───────────────

class _FormCard extends StatelessWidget {
  final IconData icon;
  final Color    accent;
  final String   title;
  final Widget   child;

  const _FormCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    letterSpacing: -0.2)),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool   isRequired;
  final Widget child;

  const _LabeledField({
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kLabel)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 15),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
    );
