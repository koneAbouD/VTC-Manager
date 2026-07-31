import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../../../features/vehicule/domain/entities/vehicule.dart';
import '../../../../features/vehicule/presentation/pages/vehicule_selector_page.dart';
import '../../../operation_financiere/domain/entities/detail_maintenance.dart';
import '../../../operation_financiere/domain/entities/element_maintenance.dart';
import '../../../operation_financiere/presentation/pages/elements_maintenance_page.dart';
import '../../../operation_financiere/domain/entities/categorie_operation.dart';
import '../../../partenaire/presentation/providers/partenaire_providers.dart';
import '../../domain/entities/maintenance.dart';
import '../providers/maintenance_provider.dart';
import '../providers/type_maintenance_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../../etat_parc/presentation/providers/etat_parc_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kPrimary = AppColors.primary;
const _kAccent = Color(0xFFE65100);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint = Color(0xFF9AA0AE);
const _kLabel = Color(0xFF6B7280);
const _kBorder = Color(0xFFE3E6EE);
const _kDark = Color(0xFF1A1A2E);
const _kError = Color(0xFFE03131);

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
      duration: error ? const Duration(seconds: 4) : const Duration(seconds: 2),
    ));
}

// ── Page ──────────────────────────────────────────────────────────────────────

class MaintenanceFormPage extends ConsumerStatefulWidget {
  final Maintenance? initial;
  const MaintenanceFormPage({super.key, this.initial});

  @override
  ConsumerState<MaintenanceFormPage> createState() =>
      _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends ConsumerState<MaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _submitError;

  CategorieOperation? _categorieType;
  DateTime? _datePrevue;
  final _dureeCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  /// Partenaire ayant réalisé l'intervention, choisi dans le répertoire.
  int? _partenaireId;
  String? _partenaireNom;

  int? _vehiculeId;
  String? _vehiculeNom;

  bool _elementsExpanded = true;
  List<ElementMaintenance> _elements = [];

  bool get _isEdit => widget.initial != null;

  bool _refRafraichi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchit une seule fois les types de maintenance (données de référence
    // éditées ailleurs, ex. ReferentielListePage) pour que le sélecteur reflète
    // toute création / modification récente. Ici (et non dans initState) car
    // `ref.invalidate` dépend du ProviderScope, indisponible pendant initState.
    if (!_refRafraichi) {
      _refRafraichi = true;
      ref.invalidate(typeMaintenanceProvider('Maintenances'));
    }
  }

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    if (m != null) {
      _datePrevue = m.datePrevue;
      _dureeCtrl.text = m.dureeHeures?.toString() ?? '';
      _descriptionCtrl.text = m.description ?? '';
      _partenaireId = m.partenaireId;
      _partenaireNom = m.partenaireNom;
      _vehiculeId = m.vehiculeId;
      _vehiculeNom = m.vehiculeNom;
      if (m.detailMaintenance != null) {
        _elements = List.from(m.detailMaintenance!.elements);
      }
    } else {
      _datePrevue = DateTime.now();
    }
  }

  @override
  void dispose() {
    _dureeCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _datePrevue ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      ),
    );
    if (picked != null) setState(() => _datePrevue = picked);
  }

  Future<void> _openVehiculeSelector() async {
    final result = await Navigator.push<Vehicule>(
      context,
      MaterialPageRoute(builder: (_) => const VehiculeSelectorPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _vehiculeId = result.id;
        _vehiculeNom = result.immatriculation;
      });
    }
  }

  Future<void> _openElementsPage() async {
    final result = await Navigator.push<List<ElementMaintenance>>(
      context,
      MaterialPageRoute(
          builder: (_) => ElementsMaintenancePage(
              initial: _elements, partenaireDefautNom: _partenaireNom)),
    );
    if (result != null && mounted) {
      setState(() => _elements = List.from(result));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitError = null);
    if (_datePrevue == null) {
      _showToast(context, 'Veuillez sélectionner une date prévue', error: true);
      return;
    }

    setState(() => _loading = true);

    if (_categorieType == null) {
      _showToast(context, 'Veuillez sélectionner un type de maintenance',
          error: true);
      setState(() => _loading = false);
      return;
    }

    final maintenance = Maintenance(
      id: widget.initial?.id,
      type: _categorieType!.code,
      datePrevue: _datePrevue!,
      dureeHeures: int.tryParse(_dureeCtrl.text),
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      // Champ kilométrage retiré du formulaire : on conserve la valeur
      // existante en édition pour ne pas l'écraser.
      kilometrageAuMoment: widget.initial?.kilometrageAuMoment,
      partenaireId: _partenaireId,
      partenaireNom: _partenaireNom,
      vehiculeId: _vehiculeId,
      categorieTypeId: _categorieType!.id,
      categorieTypeLibelle: _categorieType!.libelle,
      detailMaintenance:
          _elements.isNotEmpty ? DetailMaintenance(elements: _elements) : null,
    );

    final notifier = ref.read(maintenanceNotifierProvider.notifier);
    final error = _isEdit
        ? await notifier.updateMaintenance(widget.initial!.id!, maintenance)
        : await notifier.createMaintenance(maintenance);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _submitError = error);
      _showToast(context, error, error: true);
    } else {
      // Deux raisons de rafraîchir les Finances : une date prévue déjà passée
      // fait terminer la maintenance côté serveur (dépense générée), et une
      // modification réaligne les dettes de l'intervention sur son nouveau coût.
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final estPassee = !_isEdit && _datePrevue!.isBefore(today);
      if (estPassee || _isEdit) refreshFinances(ref);

      // Une maintenance modifie l'état du véhicule (immobilisation, retour en
      // service) : rafraîchir la photo de l'État de parc.
      ref.invalidate(etatParcSummaryProvider);

      // Pas d'alerte de succès : la fermeture + le refresh de la liste suffisent.
      Navigator.pop(context, true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppHeader(
        title: _isEdit ? 'Modifier maintenance' : 'Nouvelle maintenance',
        action: AppHeaderAction(
          icon: Icons.check_rounded,
          loading: _loading,
          onTap: _save,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_submitError != null) ...[
              AppErrorBanner(
                message: _submitError!,
                onClose: () => setState(() => _submitError = null),
              ),
              const SizedBox(height: 16),
            ],

            // ── Planification ────────────────────────────────────
            _FormCard(
              icon: Icons.event_note_outlined,
              accent: _kPrimary,
              title: 'Planification',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LabeledField(
                    label: 'Type de maintenance',
                    isRequired: true,
                    child: _TypeDropdown(
                      selected: _categorieType,
                      onChanged: (cat) => setState(() => _categorieType = cat),
                      initial: widget.initial,
                      onInitResolved: (cat) {
                        if (_categorieType == null && cat != null) {
                          setState(() => _categorieType = cat);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _LabeledField(
                          label: 'Date prévue',
                          isRequired: true,
                          child: _buildDateField(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LabeledField(
                          label: 'Durée (h)',
                          child: TextFormField(
                            controller: _dureeCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 15, color: _kDark),
                            decoration: _fieldDeco('ex: 3'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Véhicule ─────────────────────────────────────────
            _FormCard(
              icon: Icons.directions_car_outlined,
              accent: _kPrimary,
              title: 'Véhicule',
              child: _LabeledField(
                label: 'Véhicule concerné',
                child: _buildSelectorField(
                  hint: 'Sélectionner un véhicule',
                  value: _vehiculeNom,
                  onTap: _openVehiculeSelector,
                  onClear: _vehiculeNom != null
                      ? () => setState(() {
                            _vehiculeId = null;
                            _vehiculeNom = null;
                          })
                      : null,
                ),
              ),
            ),

            // ── Éléments concernés ───────────────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(children: [
                GestureDetector(
                  onTap: () =>
                      setState(() => _elementsExpanded = !_elementsExpanded),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kAccent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.checklist_rounded,
                            size: 18, color: _kAccent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Éléments concernés',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kDark,
                                  letterSpacing: -0.2),
                            ),
                            if (_elements.isNotEmpty)
                              Text(
                                '${_elements.length} élément${_elements.length > 1 ? 's' : ''} · '
                                '${_elements.fold(0.0, (s, e) => s + e.montant).toStringAsFixed(0)} XOF',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: _kAccent,
                                    fontWeight: FontWeight.w500),
                              ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _elementsExpanded ? 0.5 : 0.0,
                        duration: const Duration(milliseconds: 250),
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: _kHint),
                      ),
                    ]),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _elementsExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: _buildElementsSelector(),
                        )
                      : const SizedBox.shrink(),
                ),
              ]),
            ),

            // ── Détails ──────────────────────────────────────────
            _FormCard(
              icon: Icons.notes_outlined,
              accent: _kPrimary,
              title: 'Détails',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Le partenaire de l'intervention ne se demande que s'il sert
                  // encore : dès que chaque élément a son prestataire, il n'a
                  // plus rien à couvrir et le champ disparaît.
                  if (_partenaireUtile) ...[
                    _LabeledField(
                      label: _elementsRepartis
                          ? 'Partenaire (éléments sans prestataire)'
                          : 'Partenaire',
                      child: _champPartenaire(),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    _bandeauPrestatairesRepartis(),
                    const SizedBox(height: 12),
                  ],
                  _LabeledField(
                    label: 'Description',
                    child: TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco('Travaux prévus…'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 17, color: _kPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _datePrevue != null
                  ? DateFormat('dd MMM yyyy', 'fr_FR').format(_datePrevue!)
                  : 'Sélectionner',
              style: TextStyle(
                  fontSize: 15, color: _datePrevue != null ? _kDark : _kHint),
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: _kHint),
        ]),
      ),
    );
  }

  Widget _buildSelectorField({
    required String hint,
    String? value,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              value ?? hint,
              style: TextStyle(
                  fontSize: 15, color: value == null ? _kHint : _kDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (value != null && onClear != null)
            GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18, color: _kHint))
          else
            const Icon(Icons.chevron_right, size: 20, color: _kHint),
        ]),
      ),
    );
  }

  Widget _buildElementsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_elements.isNotEmpty) ...[
          ..._elements.map((el) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.20)),
                ),
                child: Row(children: [
                  const Icon(Icons.build_circle_outlined,
                      size: 15, color: _kAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      el.libelleAvecQuantite,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: _kDark),
                    ),
                  ),
                  Text(
                    '${el.montant.toStringAsFixed(0)} XOF',
                    style: const TextStyle(
                        fontSize: 12,
                        color: _kAccent,
                        fontWeight: FontWeight.w600),
                  ),
                ]),
              )),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: _openElementsPage,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _kFieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.checklist_rounded, size: 17, color: _kPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _elements.isEmpty
                      ? 'Sélectionner les éléments'
                      : 'Modifier la sélection',
                  style: TextStyle(
                      fontSize: 15, color: _elements.isEmpty ? _kHint : _kDark),
                ),
              ),
              if (_elements.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kAccent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_elements.length}',
                    style: const TextStyle(
                        color: _kAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: _kHint),
            ]),
          ),
        ),
      ],
    );
  }

  /// Vrai dès qu'un élément porte son propre prestataire.
  bool get _elementsRepartis => _elements.any((e) => e.partenaireId != null);

  /// Le partenaire de l'intervention couvre les éléments qui n'en ont pas —
  /// et l'écart éventuel entre le coût validé et la somme des lignes. Il ne
  /// devient inutile que lorsque toutes les lignes sont attribuées.
  bool get _partenaireUtile =>
      _elements.isEmpty || _elements.any((e) => e.partenaireId == null);

  /// Remplace le champ quand la répartition est complète : l'information reste
  /// visible, sans demander une saisie qui ne servirait à rien.
  Widget _bandeauPrestatairesRepartis() {
    final noms = <String>{
      for (final e in _elements)
        if (e.partenaireNom != null && e.partenaireNom!.isNotEmpty)
          e.partenaireNom!,
    }.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.groups_2_outlined, size: 18, color: _kAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prestataires définis par élément',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kAccent)),
                if (noms.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(noms.join(' · '),
                      style: const TextStyle(fontSize: 11.5, color: _kLabel)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sélecteur de partenaire, alimenté par le répertoire des partenaires
  /// actifs. Un partenaire absent se crée depuis l'écran Partenaires.
  Widget _champPartenaire() {
    final partenaires = ref.watch(partenairesProvider(true));
    return partenaires.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Partenaires indisponibles : $e',
          style: const TextStyle(fontSize: 12, color: AppColors.error)),
      data: (liste) {
        // Un partenaire désactivé depuis la saisie reste affiché, sinon
        // l'intervention perdrait son prestataire à la première modification.
        final options = liste
            .where((p) => p.id != null)
            .map((p) => SelectOption(
                value: p.id!, label: p.nom, sousTitre: p.typeNom))
            .toList();
        if (_partenaireId != null &&
            !options.any((o) => o.value == _partenaireId)) {
          options.insert(
              0,
              SelectOption(
                  value: _partenaireId!,
                  label: _partenaireNom ?? 'Partenaire #$_partenaireId'));
        }
        return PremiumSelectField<int>(
          value: _partenaireId,
          hint: 'Garage, atelier…',
          sheetTitle: 'Choisir le partenaire',
          options: options,
          onChanged: (v) => setState(() {
            _partenaireId = v;
            _partenaireNom = v == null
                ? null
                : liste.firstWhere((p) => p.id == v,
                    orElse: () => liste.first).nom;
          }),
        );
      },
    );
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
}

// ── Dropdown type de maintenance chargé depuis le backend ────────────────────

class _TypeDropdown extends ConsumerStatefulWidget {
  final CategorieOperation? selected;
  final void Function(CategorieOperation?) onChanged;
  final Maintenance? initial;
  final void Function(CategorieOperation?) onInitResolved;

  const _TypeDropdown({
    required this.selected,
    required this.onChanged,
    required this.initial,
    required this.onInitResolved,
  });

  @override
  ConsumerState<_TypeDropdown> createState() => _TypeDropdownState();
}

class _TypeDropdownState extends ConsumerState<_TypeDropdown> {
  @override
  Widget build(BuildContext context) {
    final async = ref.watch(typeMaintenanceProvider('Maintenances'));
    final isLoading = async is AsyncLoading;
    final categories = async.value ?? [];

    // Pré-sélectionner si édition et pas encore résolu
    if (widget.selected == null && widget.initial?.categorieTypeId != null) {
      final found = categories
          .where((c) => c.id == widget.initial!.categorieTypeId)
          .firstOrNull;
      if (found != null) {
        Future.microtask(() => widget.onInitResolved(found));
      }
    }

    final selectedId = widget.selected?.id;

    if (isLoading) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(children: [
          const Expanded(
            child: Text('Sélectionner un type',
                style: TextStyle(color: _kHint, fontSize: 14)),
          ),
          SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
                strokeWidth: 1.8, color: Colors.grey.shade400),
          ),
        ]),
      );
    }

    return PremiumSelectField<int>(
      value: selectedId != null && categories.any((c) => c.id == selectedId)
          ? selectedId
          : null,
      hint: 'Sélectionner un type',
      sheetTitle: 'Type de maintenance',
      fillColor: _kFieldFill,
      options: categories
          .map((c) => SelectOption<int>(value: c.id, label: c.libelle))
          .toList(),
      onChanged: (id) {
        final cat = categories.where((c) => c.id == id).firstOrNull;
        widget.onChanged(cat);
      },
    );
  }
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;

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
  final bool isRequired;
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
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: _kLabel)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kError, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
