import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../maintenance/presentation/providers/type_maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/maintenance_visuels.dart';
import '../providers/catalogue_elements_providers.dart';
import '../providers/parametrage_providers.dart';
import '../widgets/champ_image_referentiel.dart';
import '../widgets/cible_vehicule_catalogue.dart';

/// Création / modification d'un élément du catalogue de maintenance.
///
/// Remplace pour ce référentiel le formulaire générique : le véhicule concerné
/// se choisit en un seul champ (la marque se déduit du modèle), et le type de
/// maintenance en puces à icônes, « Commun à tous » compris.
class CatalogueElementMaintenanceFormPage extends ConsumerStatefulWidget {
  /// Élément à modifier ; null pour une création.
  final Map<String, dynamic>? item;

  /// Type déjà choisi pour une création lancée depuis une section de la liste.
  final int? categorieTypeInitialeId;

  const CatalogueElementMaintenanceFormPage(
      {super.key, this.item, this.categorieTypeInitialeId});

  @override
  ConsumerState<CatalogueElementMaintenanceFormPage> createState() =>
      _CatalogueElementMaintenanceFormPageState();
}

class _CatalogueElementMaintenanceFormPageState
    extends ConsumerState<CatalogueElementMaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelleCtrl;
  late final TextEditingController _montantCtrl;
  int? _typeId;
  late CibleVehicule _cible;
  String? _image;
  String? _imagePreview;
  bool _saving = false;

  bool get _edition => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _libelleCtrl = TextEditingController(text: item?['libelle'] as String? ?? '');
    final montant = item?['montantDefaut'] as num?;
    _montantCtrl = TextEditingController(
        text: montant == null ? '' : montant.toStringAsFixed(0));
    _typeId = item != null
        ? (item['categorieTypeId'] as num?)?.toInt()
        : widget.categorieTypeInitialeId;
    _cible = item != null ? CibleVehicule.depuisElement(item) : CibleVehicule.tous;
    _image = item?['image'] as String?;
    _imagePreview = item?['imageUrl'] as String?;
  }

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  Future<void> _choisirVehicule() async {
    final choix = await choisirCibleVehicule(context, actuelle: _cible);
    if (choix != null && mounted) setState(() => _cible = choix);
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final montantSaisi = _montantCtrl.text.trim().replaceAll(' ', '');
    final body = <String, dynamic>{
      'libelle': _libelleCtrl.text.trim(),
      'categorieTypeId': _typeId,
      ..._cible.versCorps(),
      'montantDefaut': montantSaisi.isEmpty
          ? null
          : num.tryParse(montantSaisi.replaceAll(',', '.')),
      'image': _image,
    };
    setState(() => _saving = true);
    try {
      final api = ref.read(parametrageApiProvider);
      if (_edition) {
        await api.mettreAJour(
            kEndpointCatalogueElements, widget.item!['id'] as Object, body);
      } else {
        await api.creer(kEndpointCatalogueElements, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _toast(_message(e), erreur: true);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String message, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: erreur ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ));
  }

  String _message(Object e) {
    try {
      final m = (e as dynamic).message;
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return 'Enregistrement impossible.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
          title: _edition ? 'Modifier l\'élément' : 'Nouvel élément'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 14),
                  _label('Libellé', obligatoire: true),
                  TextFormField(
                    controller: _libelleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _deco('Ex. Filtre à huile'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Champ obligatoire'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Type de maintenance'),
                  _champType(),
                  const SizedBox(height: 16),
                  _label('Véhicule concerné'),
                  _champVehicule(),
                  const SizedBox(height: 16),
                  _label('Montant par défaut'),
                  TextFormField(
                    controller: _montantCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('Facultatif', suffixe: 'XOF'),
                  ),
                  const SizedBox(height: 16),
                  _label('Image'),
                  ChampImageReferentiel(
                    endpoint: kEndpointCatalogueElements,
                    titre: 'Image',
                    previewUrl: _imagePreview,
                    onChanged: (image, url) => setState(() {
                      _image = image;
                      _imagePreview = url;
                    }),
                    onErreur: (message) => _toast(message, erreur: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.scaffold,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _enregistrer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.border,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 19),
                label: Text(_edition ? 'Enregistrer' : 'Créer',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Type de maintenance ────────────────────────────────────────────────────

  Widget _champType() {
    final async = ref.watch(typeMaintenanceProvider('Maintenances'));
    final types = async.valueOrNull ?? const [];
    if (async.isLoading && types.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    // Un type désactivé depuis reste affiché s'il est celui de l'élément.
    final visibles =
        types.where((t) => t.actif || t.id == _typeId).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in visibles)
          _puceType(
            libelle: t.libelle,
            icone: TypeMaintenanceVisuel.icone(code: t.code, libelle: t.libelle),
            choisi: _typeId == t.id,
            onTap: () => setState(() => _typeId = t.id),
          ),
        _puceType(
          libelle: 'Commun à tous',
          icone: Icons.all_inclusive_rounded,
          choisi: _typeId == null,
          onTap: () => setState(() => _typeId = null),
        ),
      ],
    );
  }

  Widget _puceType({
    required String libelle,
    required IconData icone,
    required bool choisi,
    required VoidCallback onTap,
  }) {
    final accent = AppColors.primary;
    return Semantics(
      button: true,
      selected: choisi,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: choisi ? accent.withValues(alpha: 0.12) : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: choisi ? accent.withValues(alpha: 0.6) : Colors.transparent),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, size: 15, color: choisi ? accent : AppColors.label),
            const SizedBox(width: 5),
            Text(libelle,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: choisi ? FontWeight.w700 : FontWeight.w500,
                    color: choisi ? accent : AppColors.dark)),
          ]),
        ),
      ),
    );
  }

  // ── Véhicule concerné ─────────────────────────────────────────────────────

  Widget _champVehicule() {
    final flotte = ref.watch(modelesFlotteProvider).valueOrNull ?? const [];
    final dansFlotte = _cible.estModele &&
        flotte.any((m) => m.modeleId == _cible.modeleId);
    final precision = _cible.estModele
        ? (dansFlotte ? 'Modèle de la flotte' : 'Modèle')
        : _cible.estMarque
            ? 'Marque entière'
            : 'Proposé pour toute la flotte';
    return GestureDetector(
      onTap: _choisirVehicule,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(
            _cible.estMarque
                ? Icons.sell_outlined
                : _cible.estModele
                    ? Icons.directions_car_outlined
                    : Icons.public_rounded,
            size: 20,
            color: AppColors.label,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_cible.libelle,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
                Text(precision,
                    style: TextStyle(fontSize: 12, color: AppColors.label)),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.hint),
        ]),
      ),
    );
  }

  // ── Habillage ─────────────────────────────────────────────────────────────

  Widget _label(String libelle, {bool obligatoire = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: RichText(
          text: TextSpan(
            text: libelle,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dark),
            children: obligatoire
                ? [
                    TextSpan(
                        text: ' *', style: TextStyle(color: AppColors.error))
                  ]
                : null,
          ),
        ),
      );

  InputDecoration _deco(String hint, {String? suffixe}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.hint, fontSize: 14),
        suffixText: suffixe,
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
