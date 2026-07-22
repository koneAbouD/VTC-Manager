import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/vehicule/domain/entities/vehicule.dart';
import '../../../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../../../features/vehicule/presentation/providers/vehicule_state.dart';
import '../../../features/cotisation/domain/entities/encaissement_cotisation.dart';
import '../../../features/cotisation/domain/entities/ligne_cotisation.dart';
import '../../../features/cotisation/domain/entities/ligne_cotisation_filtres.dart';
import '../../../features/cotisation/presentation/providers/ligne_cotisation_provider.dart';
import '../../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../../features/recette/domain/entities/encaissement.dart';
import '../../../features/recette/domain/entities/ligne_recette.dart';
import '../../../features/recette/presentation/providers/ligne_recette_provider.dart';

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

// ── Toast ─────────────────────────────────────────────────────────────────────

void _showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
      ]),
      backgroundColor:
          error ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration:
          error ? const Duration(seconds: 4) : const Duration(seconds: 2),
    ));
}

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

  // ── Formulaire ─────────────────────────────────────────────────────────────
  final _montantCtrl  = TextEditingController();
  final _commentCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool  _submitting   = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _montantCtrl.addListener(() => setState(() {}));
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

  double get _recetteRestant {
    if (_ligneRecette == null) return 0;
    return _ligneRecette!.montantRestant ?? double.maxFinite;
  }

  double get _cotisationRestant {
    if (_ligneCotisation == null) return 0;
    final l = _ligneCotisation!;
    return l.montantRestant ?? (l.montantDu - l.montantEncaisse);
  }

  // ── Répartition : recette d'abord, cotisation ensuite ─────────────────────

  ({double recette, double cotisation}) get _distribution {
    final montant =
        double.tryParse(_montantCtrl.text.replaceAll(',', '.')) ?? 0;
    if (montant <= 0) return (recette: 0, cotisation: 0);
    final recettePart     = montant.clamp(0.0, _recetteRestant);
    final cotisationPart  = (montant - recettePart).clamp(0.0, _cotisationRestant);
    return (recette: recettePart, cotisation: cotisationPart);
  }

  // ── Chargement des lignes après sélection du véhicule ─────────────────────

  Future<void> _chargerLignes(Vehicule v) async {
    setState(() {
      _vehicule     = v;
      _lignesStatus = _LignesStatus.loading;
      _ligneRecette = null;
      _ligneCotisation = null;
      _lignesError  = null;
      _montantCtrl.clear();
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
    });
  }

  // ── Soumission ─────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    final dist       = _distribution;
    final commentaire = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();
    final now = DateTime.now();

    String? error;

    if (dist.recette > 0 && _ligneRecette != null) {
      error = await _encaisserRecette(dist.recette, commentaire, now);
    }

    if (error == null && dist.cotisation > 0 && _ligneCotisation != null) {
      error = await _encaisserCotisation(dist.cotisation, commentaire, now);
    }

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
    _showToast(context, 'Encaissement effectué avec succès');
  }

  Future<String?> _encaisserRecette(
      double montant, String? commentaire, DateTime date) async {
    final repo = ref.read(ligneRecetteRepositoryProvider);
    final enc  = Encaissement(
      ligneRecetteId:   _ligneRecette!.id!,
      montant:          montant,
      modeEncaissement: ModeEncaissement.especes,
      dateEncaissement: date,
      commentaire:      commentaire,
    );
    final r = await repo.createEncaissement(_ligneRecette!.id!, enc);
    return r.fold((f) => f.message, (_) => null);
  }

  Future<String?> _encaisserCotisation(
      double montant, String? commentaire, DateTime date) async {
    final repo = ref.read(ligneCotisationRepositoryProvider);
    final enc  = EncaissementCotisation(
      ligneCotisationId: _ligneCotisation!.id!,
      montant:           montant,
      modeEncaissement:  ModePaiementCotisation.especes,
      dateEncaissement:  date,
      commentaire:       commentaire,
    );
    final r = await repo.createEncaissement(_ligneCotisation!.id!, enc);
    return r.fold((f) => f.message, (_) => null);
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

    final recetteMax   = _ligneRecette?.montantRestant;
    final cotisMax     = _ligneCotisation?.montantRestant ??
        (_ligneCotisation != null
            ? _ligneCotisation!.montantDu - _ligneCotisation!.montantEncaisse
            : null);
    final totalRestantConnu = (recetteMax != null && cotisMax != null)
        ? recetteMax + cotisMax
        : (recetteMax ?? cotisMax);

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
                ligneRecette:    _ligneRecette,
                ligneCotisation: _ligneCotisation,
                fmt:             fmt,
              ),
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
                      child: TextFormField(
                        controller: _montantCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: const TextStyle(fontSize: 15, color: _kDark),
                        decoration: _fieldDeco('0').copyWith(
                          suffixText: 'XOF',
                          suffixStyle: const TextStyle(
                              color: _kLabel,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        validator: (v) {
                          final val = double.tryParse(
                              v?.replaceAll(',', '.') ?? '');
                          if (val == null || val <= 0) {
                            return 'Montant invalide';
                          }
                          if (totalRestantConnu != null &&
                              val > totalRestantConnu) {
                            return 'Dépasse le total restant'
                                ' (${fmt.format(totalRestantConnu)})';
                          }
                          return null;
                        },
                      ),
                    ),

                    // Répartition en temps réel
                    if (dist.recette > 0 || dist.cotisation > 0) ...[
                      const SizedBox(height: 10),
                      _RepartitionCard(
                        recette:    _ligneRecette    != null ? dist.recette    : null,
                        cotisation: _ligneCotisation != null ? dist.cotisation : null,
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
                onPressed: (_submitting || lignesLoading || !lignesOk)
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
  final NumberFormat     fmt;

  const _LignesCard({
    required this.ligneRecette,
    required this.ligneCotisation,
    required this.fmt,
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
            const Text('Lignes actives trouvées',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kDark,
                    letterSpacing: -0.2)),
          ]),
          const SizedBox(height: 14),

          // Recette
          if (ligneRecette != null)
            _LigneBadge(
              icon:    Icons.account_balance_wallet_outlined,
              label:   'Recette',
              montant: ligneRecette!.montantRestant != null
                  ? fmt.format(ligneRecette!.montantRestant!)
                  : '—',
              color:   _kGreen,
            ),

          if (ligneRecette != null && ligneCotisation != null)
            Divider(height: 16, color: Colors.grey.shade100),

          // Cotisation
          if (ligneCotisation != null)
            _LigneBadge(
              icon:    Icons.analytics_outlined,
              label:   ligneCotisation!.nomCotisation,
              montant: fmt.format(
                ligneCotisation!.montantRestant ??
                    (ligneCotisation!.montantDu -
                        ligneCotisation!.montantEncaisse),
              ),
              color:   _kOrange,
            ),
        ],
      ),
    );
  }
}

class _LigneBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   montant;
  final Color    color;

  const _LigneBadge({
    required this.icon,
    required this.label,
    required this.montant,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: color),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kDark)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Restant : $montant',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color),
        ),
      ),
    ]);
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
