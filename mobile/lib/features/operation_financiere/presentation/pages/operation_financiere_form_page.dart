import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/responsive_field_row.dart';
import '../../../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../../../features/chauffeur/presentation/pages/chauffeur_selector_page.dart';
import '../../../../features/vehicule/domain/entities/vehicule.dart';
import '../../../../features/vehicule/presentation/pages/vehicule_selector_page.dart';
import '../../domain/entities/categorie_operation.dart';
import '../../domain/entities/element_maintenance.dart';
import '../../domain/entities/operation_financiere.dart';
import '../../domain/enums/mode_paiement.dart';
import '../../domain/enums/type_operation.dart';
import '../providers/operation_financiere_provider.dart';
import 'categorie_operation_selector_page.dart';
import 'elements_maintenance_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kPrimary   = Color(0xFF43A047);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint      = Color(0xFF9AA0AE);
const _kLabel     = Color(0xFF6B7280);
const _kBorder    = Color(0xFFE3E6EE);
const _kDark      = Color(0xFF1A1A2E);
const _kRevenu    = Color(0xFF2F9E44);
const _kDepense   = Color(0xFFE03131);

// ── Toast ─────────────────────────────────────────────────────────────────────

void _showToast(BuildContext context, String message, {bool error = false}) {
  final bg   = error ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20);
  final icon = error
      ? Icons.error_outline_rounded
      : Icons.check_circle_outline_rounded;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: error
          ? const Duration(seconds: 4)
          : const Duration(seconds: 2),
    ));
}

// ── Page ──────────────────────────────────────────────────────────────────────

class OperationFinanciereFormPage extends ConsumerStatefulWidget {
  final TypeOperation? initialType;
  final OperationFinanciere? initial;

  const OperationFinanciereFormPage({
    super.key,
    this.initialType,
    this.initial,
  });

  @override
  ConsumerState<OperationFinanciereFormPage> createState() => _FormState();
}

class _FormState extends ConsumerState<OperationFinanciereFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _submitError;

  late TypeOperation _type;
  CategorieOperation? _categorie;
  int? _chauffeurId;
  String? _chauffeurNom;
  int? _vehiculeId;
  String? _vehiculeNom;
  final _montantCtrl = TextEditingController();
  ModePaiement _modePaiement = ModePaiement.ESPECES;
  DateTime _date = DateTime.now();
  final _commentaireCtrl = TextEditingController();

  bool _maintenanceExpanded = true;

  final _dureeCtrl = TextEditingController();
  List<ElementMaintenance> _elements = [];

  /// Libellé de la sous-catégorie de l'opération sélectionnée.
  /// Initialisé depuis l'opération en édition, mis à jour à chaque
  /// sélection de catégorie via le sélecteur.
  String? _sousCategorieLibelle;

  /// Vrai si la catégorie choisie appartient au groupe "Maintenances"
  /// (indépendant du code de catégorie — vérifié sur le libellé backend).
  bool get _isMaintenance =>
      _sousCategorieLibelle?.toLowerCase() == 'maintenances';

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ??
        widget.initial?.typeOperation ??
        TypeOperation.REVENU;

    final op = widget.initial;
    if (op != null) {
      _montantCtrl.text = op.montant.toStringAsFixed(0);
      _date = op.dateOperation;
      _modePaiement = op.modePaiement ?? ModePaiement.ESPECES;
      _commentaireCtrl.text = op.commentaire ?? '';
      _chauffeurId  = op.chauffeurId;
      _chauffeurNom = op.chauffeurNom;
      _vehiculeId   = op.vehiculeId;
      _vehiculeNom  = op.vehiculeNom;
      if (op.categorieId != null) {
        _categorie = CategorieOperation(
          id: op.categorieId!,
          code: op.categorieCode ?? '',
          libelle: op.categorieLibelle ?? '',
          typeOperation: _type,
          actif: true,
        );
        // Conserver le groupe (sous-catégorie libellé) pour _isMaintenance
        _sousCategorieLibelle = op.sousCategorieLibelle;
      }
      if (op.detailMaintenance != null) {
        _dureeCtrl.text =
            op.detailMaintenance!.dureeMaintenance?.toString() ?? '';
        _elements = List.from(op.detailMaintenance!.elements);
      }
    }
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _commentaireCtrl.dispose();
    _dureeCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
      ),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitError = null);
    if (_categorie == null) {
      _showToast(context, 'Veuillez sélectionner une catégorie', error: true);
      return;
    }
    if (_isMaintenance && _elements.isEmpty) {
      _showToast(context, 'Ajoutez au moins un élément de maintenance',
          error: true);
      return;
    }

    setState(() => _loading = true);

    final payload = <String, dynamic>{
      'typeOperation': _type.name,
      'categorieId': _categorie!.id,
      if (_chauffeurId != null) 'chauffeurId': _chauffeurId,
      if (_vehiculeId != null) 'vehiculeId': _vehiculeId,
      'montant': double.tryParse(
              _montantCtrl.text.replaceAll(',', '.').replaceAll(' ', '')) ??
          0,
      'modePaiement': _modePaiement.name,
      'dateOperation': DateFormat('yyyy-MM-dd').format(_date),
      if (_commentaireCtrl.text.trim().isNotEmpty)
        'commentaire': _commentaireCtrl.text.trim(),
      if (_isMaintenance && _elements.isNotEmpty)
        'detailMaintenance': {
          if (_dureeCtrl.text.isNotEmpty)
            'dureeMaintenance': int.tryParse(_dureeCtrl.text),
          'elements': _elements
              .map((e) => {
                    if (e.catalogueElementId != null)
                      'catalogueElementId': e.catalogueElementId,
                    if (e.libelle != null && e.libelle!.isNotEmpty)
                      'libelle': e.libelle,
                    'montant': e.montant,
                  })
              .toList(),
        },
    };

    String? error;
    if (_isEdit) {
      error = await ref
          .read(operationFinanciereNotifierProvider.notifier)
          .update(widget.initial!.id!, payload);
    } else {
      error = await ref
          .read(operationFinanciereNotifierProvider.notifier)
          .create(payload);
    }

    setState(() => _loading = false);

    if (mounted) {
      if (error != null) {
        setState(() => _submitError = error);
        _showToast(context, error, error: true);
      } else {
        _showToast(
            context, _isEdit ? 'Opération modifiée' : 'Opération créée');
        Navigator.pop(context);
      }
    }
  }

  Future<void> _openCategorieSelector() async {
    final result = await Navigator.push<CategorieOperation>(
      context,
      MaterialPageRoute(
          builder: (_) => CategorieOperationSelectorPage(
                typeOperation: _type,
                // Opération manuelle : on masque les catégories gérées
                // automatiquement (encaissements et maintenances).
                exclureSousCategories: const {'Encaissement', 'Maintenances'},
              )),
    );
    if (result != null && mounted) {
      setState(() {
        _categorie = result;
        // Le groupe est porté par la sous-catégorie (libellé côté backend)
        _sousCategorieLibelle = result.sousCategorie?.libelle;
        if (_isMaintenance) {
          _maintenanceExpanded = true;
          // Recalculer si des éléments existent déjà (mode édition)
          if (_elements.isNotEmpty) _updateMontantFromElements(_elements);
        } else {
          // Hors groupe Maintenances → vider les éléments
          _elements = [];
        }
      });
    }
  }

  Future<void> _openChauffeurSelector() async {
    final result = await Navigator.push<Chauffeur>(
      context,
      MaterialPageRoute(builder: (_) => const ChauffeurSelectorPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _chauffeurId  = result.id;
        _chauffeurNom = result.displayName;
        if (result.vehiculeId != null) {
          _vehiculeId  = result.vehiculeId;
          _vehiculeNom = result.vehiculeNom ?? result.vehiculeModele;
        }
      });
    }
  }

  Future<void> _openVehiculeSelector() async {
    final result = await Navigator.push<Vehicule>(
      context,
      MaterialPageRoute(builder: (_) => const VehiculeSelectorPage()),
    );
    if (result != null && mounted) {
      setState(() {
        _vehiculeId  = result.id;
        _vehiculeNom = result.displayName;
      });
    }
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  Widget _buildModePaiementToggle() {
    return Row(
      children: ModePaiement.values.map((m) {
        final isSel     = _modePaiement == m;
        final isEspeces = m == ModePaiement.ESPECES;
        final icon      = isEspeces
            ? Icons.payments_outlined
            : Icons.phone_android_outlined;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (!isSel) setState(() => _modePaiement = m);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                  right: isEspeces ? 5 : 0, left: isEspeces ? 0 : 5),
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? _kPrimary.withValues(alpha: 0.10)
                    : _kFieldFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? _kPrimary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 15,
                      color:
                          isSel ? _kPrimary : _kHint.withValues(alpha: 0.6)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      m.libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? _kPrimary : _kHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeToggle() {
    return Row(
      children: TypeOperation.values.map((t) {
        final isSel    = _type == t;
        final isRevenu = t == TypeOperation.REVENU;
        final color    = isRevenu ? _kRevenu : _kDepense;

        return Expanded(
          child: GestureDetector(
            onTap: () {
              if (!isSel) setState(() { _type = t; _categorie = null; });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(
                  right: isRevenu ? 5 : 0, left: isRevenu ? 0 : 5),
              padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSel
                    ? color.withValues(alpha: 0.10)
                    : _kFieldFill,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSel ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSel
                          ? color
                          : _kHint.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    t.libelle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSel
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSel ? color : _kHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Sélecteur d'éléments de maintenance ──────────────────────────────────

  /// Recalcule le montant à partir des éléments de maintenance.
  void _updateMontantFromElements(List<ElementMaintenance> elements) {
    final total =
        elements.fold(0.0, (sum, e) => sum + e.montant);
    _montantCtrl.text =
        total > 0 ? total.toStringAsFixed(0) : '';
  }

  Future<void> _openElementsPage() async {
    final result = await Navigator.push<List<ElementMaintenance>>(
      context,
      MaterialPageRoute(
        builder: (_) => ElementsMaintenancePage(initial: _elements),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _elements = List.from(result);
        _updateMontantFromElements(_elements);
      });
    }
  }

  Widget _buildElementsSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_elements.isNotEmpty) ...[
          ..._elements.map((el) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE65100)
                        .withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.build_circle_outlined,
                        size: 15, color: Color(0xFFE65100)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        el.effectiveLibelle,
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
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 8),
        ],
        GestureDetector(
          onTap: _openElementsPage,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _kFieldFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.checklist_rounded,
                    size: 17, color: _kPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _elements.isEmpty
                        ? 'Sélectionner les éléments'
                        : 'Modifier la sélection',
                    style: TextStyle(
                        fontSize: 15,
                        color: _elements.isEmpty ? _kHint : _kDark),
                  ),
                ),
                if (_elements.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE65100)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_elements.length}',
                      style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 20, color: _kHint),
              ],
            ),
          ),
        ),
      ],
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 15,
                  color: value == null ? _kHint : _kDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            if (value != null && onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 18, color: _kHint),
              )
            else
              const Icon(Icons.chevron_right,
                  size: 20, color: _kHint),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 17, color: _kPrimary),
            const SizedBox(width: 10),
            Text(
              DateFormat('dd MMMM yyyy', 'fr_FR').format(_date),
              style:
                  const TextStyle(fontSize: 15, color: _kDark),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down,
                size: 20, color: _kHint),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(color: _kHint, fontSize: 15),
        filled: true,
        fillColor: _kFieldFill,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
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
          borderSide:
              const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _kDepense, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: _kDepense, width: 1.5),
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppHeader(
        title: _isEdit ? 'Modifier opération' : 'Nouvelle opération',
        action: AppHeaderAction(
          icon: Icons.check_rounded,
          loading: _loading,
          onTap: _submit,
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
                    // ── Carte principale (tout sauf maintenance) ───────
                    _FormCard(
                      icon: Icons.receipt_long_outlined,
                      accent: _kPrimary,
                      title: "Détail de l'opération",
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // — Type ───────────────────────────────────
                          _buildTypeToggle(),

                          _kCardDivider,

                          // — Chauffeur & Véhicule ───────────────────
                          ResponsiveFieldRow(
                            left: _LabeledField(
                              label: 'Chauffeur',
                              child: _buildSelectorField(
                                hint: 'Choisir',
                                value: _chauffeurNom,
                                onTap: _openChauffeurSelector,
                                onClear: () => setState(() {
                                  _chauffeurId  = null;
                                  _chauffeurNom = null;
                                }),
                              ),
                            ),
                            right: _LabeledField(
                              label: 'Véhicule',
                              child: _buildSelectorField(
                                hint: 'Choisir',
                                value: _vehiculeNom,
                                onTap: _openVehiculeSelector,
                                onClear: () => setState(() {
                                  _vehiculeId  = null;
                                  _vehiculeNom = null;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // — Catégorie ──────────────────────────────
                          _LabeledField(
                            label: 'Catégorie',
                            isRequired: true,
                            child: _buildSelectorField(
                              hint: 'Sélectionner une catégorie',
                              value: _categorie?.libelle,
                              onTap: _openCategorieSelector,
                            ),
                          ),

                          // — Accordion Éléments concernés ──────────────
                          if (_isMaintenance) ...[
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFE65100)
                                    .withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFE65100)
                                        .withValues(alpha: 0.18)),
                              ),
                              child: Column(children: [
                                // En-tête
                                GestureDetector(
                                  onTap: () => setState(() =>
                                      _maintenanceExpanded =
                                          !_maintenanceExpanded),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE65100)
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                            Icons.build_outlined,
                                            size: 15,
                                            color: Color(0xFFE65100)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text.rich(TextSpan(
                                          text: 'Éléments concernés',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _kDark,
                                            letterSpacing: -0.2,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: ' *',
                                              style: TextStyle(
                                                  color: _kDepense,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                  fontSize: 14),
                                            ),
                                          ],
                                        )),
                                      ),
                                      AnimatedRotation(
                                        turns: _maintenanceExpanded
                                            ? 0.5
                                            : 0.0,
                                        duration: const Duration(
                                            milliseconds: 250),
                                        child: const Icon(
                                            Icons
                                                .keyboard_arrow_down_rounded,
                                            size: 18,
                                            color: _kHint),
                                      ),
                                    ]),
                                  ),
                                ),
                                // Corps animé
                                AnimatedSize(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  child: _maintenanceExpanded
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.fromLTRB(
                                                  12, 0, 12, 12),
                                          child: _buildElementsSelector(),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ]),
                            ),
                          ],


                          _kCardDivider,

                          // — Montant & paiement ─────────────────────
                          ResponsiveFieldRow(
                            leftFlex: _isMaintenance ? 2 : 1,
                            left: _LabeledField(
                                  label: 'Montant (XOF)',
                                  isRequired: true,
                                  child: TextFormField(
                                    controller: _montantCtrl,
                                    readOnly: _isMaintenance,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    style: const TextStyle(
                                        fontSize: 15, color: _kDark),
                                    decoration: _isMaintenance
                                        ? _fieldDeco('0').copyWith(
                                            fillColor:
                                                const Color(0xFFEEF2FF),
                                            suffixIcon: const Padding(
                                              padding: EdgeInsets.only(
                                                  right: 10),
                                              child: Icon(
                                                Icons.calculate_outlined,
                                                size: 16,
                                                color: _kPrimary,
                                              ),
                                            ),
                                            suffixIconConstraints:
                                                const BoxConstraints(
                                                    minWidth: 0,
                                                    minHeight: 0),
                                          )
                                        : _fieldDeco('0'),
                                    validator: (v) {
                                      final d = double.tryParse(v
                                              ?.replaceAll(',', '.')
                                              .replaceAll(' ', '') ??
                                          '');
                                      if (d == null || d <= 0) {
                                        return 'Montant invalide';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                            right: _isMaintenance
                                ? _LabeledField(
                                    label: 'Durée (h)',
                                    child: TextFormField(
                                      controller: _dureeCtrl,
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(
                                          fontSize: 15, color: _kDark),
                                      decoration: _fieldDeco('ex : 2'),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _LabeledField(
                            label: 'Mode de paiement',
                            child: _buildModePaiementToggle(),
                          ),

                          _kCardDivider,

                          // — Date & informations ────────────────────
                          _LabeledField(
                            label: "Date de l'opération",
                            isRequired: true,
                            child: _buildDateField(),
                          ),
                          const SizedBox(height: 12),
                          _LabeledField(
                            label: 'Commentaire',
                            child: TextFormField(
                              controller: _commentaireCtrl,
                              maxLines: 3,
                              style: const TextStyle(
                                  fontSize: 15, color: _kDark),
                              decoration: _fieldDeco(
                                  'Informations complémentaires…'),
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
}

// ── Widgets locaux ────────────────────────────────────────────────────────────

/// Séparateur horizontal utilisé à l'intérieur d'une _FormCard fusionnée.
const _kCardDivider = Padding(
  padding: EdgeInsets.symmetric(vertical: 16),
  child: Divider(color: Color(0xFFEEF0F6), thickness: 1, height: 1),
);

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
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _kDark,
                letterSpacing: -0.2,
              ),
            ),
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kLabel,
            ),
          ),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kDepense,
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
