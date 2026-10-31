import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../../maintenance/presentation/providers/type_maintenance_provider.dart';
import '../../../maintenance/presentation/widgets/maintenance_visuels.dart';
import '../providers/catalogue_elements_providers.dart';
import '../providers/parametrage_providers.dart';
import '../widgets/champ_image_referentiel.dart';
import '../widgets/cible_vehicule_catalogue.dart';

/// Création / modification d'un élément du catalogue de maintenance.
///
/// Deux parties : ce qui vaut pour tous les modèles (libellé, type de
/// maintenance, activation) et ce qui vaut pour un modèle (prix, image,
/// proposé ou non). Depuis l'onglet d'un modèle, on peut créer un élément ou
/// lui ajouter un élément qui existe déjà pour d'autres modèles.
class CatalogueElementMaintenanceFormPage extends ConsumerStatefulWidget {
  /// Élément à modifier ; null pour une création.
  final Map<String, dynamic>? element;

  /// Modèle dont on règle le prix et l'image ; null : à choisir dans le
  /// formulaire (création depuis l'en-tête, élément sans modèle).
  final CibleVehicule? modele;

  /// Prix, image et activation actuels pour [modele].
  final num? prix;
  final String? image;
  final String? imageUrl;
  final bool tarifActif;

  /// Type déjà choisi pour une création lancée depuis une section de la liste.
  final int? categorieTypeInitialeId;

  const CatalogueElementMaintenanceFormPage({
    super.key,
    this.element,
    this.modele,
    this.prix,
    this.image,
    this.imageUrl,
    this.tarifActif = true,
    this.categorieTypeInitialeId,
  });

  @override
  ConsumerState<CatalogueElementMaintenanceFormPage> createState() =>
      _CatalogueElementMaintenanceFormPageState();
}

class _CatalogueElementMaintenanceFormPageState
    extends ConsumerState<CatalogueElementMaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _libelleCtrl;
  late final TextEditingController _prixCtrl;
  int? _typeId;
  late bool _elementActif;
  CibleVehicule? _modele;
  String? _image;
  String? _imagePreview;
  late bool _tarifActif;
  bool _saving = false;

  /// Création seulement : ajouter au modèle un élément qui existe déjà.
  bool _existant = false;
  Object? _elementExistantId;

  bool get _edition => widget.element != null;

  @override
  void initState() {
    super.initState();
    final el = widget.element;
    _libelleCtrl = TextEditingController(text: el?['libelle'] as String? ?? '');
    _prixCtrl = TextEditingController(
        text: widget.prix == null ? '' : widget.prix!.toStringAsFixed(0));
    _typeId = el != null
        ? (el['categorieTypeId'] as num?)?.toInt()
        : widget.categorieTypeInitialeId;
    _elementActif = el?['actif'] as bool? ?? true;
    _modele = widget.modele;
    _image = widget.image;
    _imagePreview = widget.imageUrl;
    _tarifActif = widget.tarifActif;
  }

  @override
  void dispose() {
    _libelleCtrl.dispose();
    _prixCtrl.dispose();
    super.dispose();
  }

  num? get _prix {
    final saisi = _prixCtrl.text.trim().replaceAll(' ', '');
    return saisi.isEmpty ? null : num.tryParse(saisi.replaceAll(',', '.'));
  }

  Future<void> _choisirModele() async {
    final choix = await choisirCibleVehicule(context,
        actuelle: _modele ?? CibleVehicule.tous,
        modelesSeulement: true,
        titre: 'Modèle de véhicule');
    if (choix != null && mounted) setState(() => _modele = choix);
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final modeleId = _modele?.modeleId;
    final api = ref.read(parametrageApiProvider);
    // Un élément concerne un modèle à la fois : à la création, il en faut un,
    // sinon l'élément ne serait proposé nulle part.
    if (!_edition && modeleId == null) {
      _toast('Choisissez le modèle de véhicule.', erreur: true);
      return;
    }
    if (!_edition && _existant && _elementExistantId == null) {
      _toast('Choisissez l\'élément à ajouter.', erreur: true);
      return;
    }

    setState(() => _saving = true);
    try {
      if (!_edition && _existant) {
        await api.enregistrerTarif(
            kEndpointCatalogueElements, _elementExistantId!, modeleId!,
            prix: _prix, image: _image, actif: true);
      } else if (!_edition) {
        await api.creer(kEndpointCatalogueElements, {
          'libelle': _libelleCtrl.text.trim(),
          'categorieTypeId': _typeId,
          'modeleId': modeleId,
          'prix': _prix,
          'image': _image,
        });
      } else {
        final id = widget.element!['id'] as Object;
        await api.mettreAJour(kEndpointCatalogueElements, id, {
          'libelle': _libelleCtrl.text.trim(),
          'categorieTypeId': _typeId,
        });
        if (_elementActif != (widget.element!['actif'] as bool? ?? true)) {
          await api.changerActivation(kEndpointCatalogueElements, id, _elementActif);
        }
        if (modeleId != null) {
          await api.enregistrerTarif(kEndpointCatalogueElements, id, modeleId,
              prix: _prix, image: _image, actif: _tarifActif);
        }
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
    final nomModele = _modele?.libelle;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
          title: _edition ? 'Modifier l\'élément' : 'Nouvel élément'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_avertissementPortee() case final message?) ...[
              _bandeau(message),
              const SizedBox(height: 12),
            ],
            // Depuis l'onglet d'un modèle : nouvel élément, ou élément déjà
            // présent pour d'autres modèles.
            if (!_edition && widget.modele != null) ...[
              _choixCreation(),
              const SizedBox(height: 12),
            ],
            _carte(
              titre: 'Pour tous les modèles',
              enfants: _existant && !_edition
                  ? [
                      _label('Élément', obligatoire: true),
                      _champElementExistant(),
                    ]
                  : [
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
                      if (_edition) ...[
                        const SizedBox(height: 10),
                        _interrupteur(
                          'Actif pour tous les modèles',
                          _elementActif,
                          (v) => setState(() => _elementActif = v),
                        ),
                      ],
                    ],
            ),
            const SizedBox(height: 12),
            _carte(
              titre: nomModele != null ? 'Pour $nomModele' : 'Pour un modèle',
              enfants: [
                if (widget.modele == null) ...[
                  _label('Modèle de véhicule', obligatoire: !_edition),
                  _champModele(),
                  const SizedBox(height: 16),
                ],
                if (_modele != null) ...[
                  _label('Prix'),
                  TextFormField(
                    controller: _prixCtrl,
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
                    fondTeinte: false,
                  ),
                  if (_edition) ...[
                    const SizedBox(height: 10),
                    _interrupteur(
                      'Proposé pour ce modèle',
                      _tarifActif,
                      (v) => setState(() => _tarifActif = v),
                    ),
                  ],
                ] else
                  Text(
                      'Choisissez un modèle pour lui donner un prix et une image.',
                      style: TextStyle(fontSize: 13, color: AppColors.label)),
              ],
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
                label: Text(
                    _edition
                        ? 'Enregistrer'
                        : _existant
                            ? 'Ajouter au modèle'
                            : 'Créer',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Portée partagée ───────────────────────────────────────────────────────

  /// Le libellé et le type d'un élément valent pour tous ses modèles : à la
  /// modification, on rappelle lesquels, et que prix et image n'engagent que
  /// le modèle affiché.
  String? _avertissementPortee() {
    if (!_edition) return null;
    final modeles = (widget.element!['tarifs'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((t) => t['modeleNom'] as String?)
        .whereType<String>()
        .toList();
    if (modeles.isEmpty) {
      return 'Cet élément n\'est proposé pour aucun modèle : choisissez-en un '
          'pour lui donner un prix.';
    }
    if (modeles.length < 2) return null;
    final liste = modeles.length == 2
        ? modeles.join(' et ')
        : '${modeles.sublist(0, modeles.length - 1).join(', ')} et ${modeles.last}';
    final modele = widget.modele?.modeleNom;
    return 'Le libellé et le type valent pour $liste.'
        '${modele != null ? ' Le prix et l\'image ne valent que pour $modele.' : ''}';
  }

  Widget _bandeau(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 18, color: AppColors.label),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      fontSize: 13, color: AppColors.dark, height: 1.35)),
            ),
          ],
        ),
      );

  // ── Nouvel élément ou élément existant ───────────────────────────────────

  Widget _choixCreation() {
    Widget segment(String libelle, bool valeur) {
      final choisi = _existant == valeur;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _existant = valeur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: choisi ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: choisi ? AppColors.border : Colors.transparent),
            ),
            child: Text(libelle,
                style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: choisi ? FontWeight.w700 : FontWeight.w500,
                    color: choisi ? AppColors.dark : AppColors.label)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        segment('Nouvel élément', false),
        segment('Élément existant', true),
      ]),
    );
  }

  /// Éléments du catalogue que ce modèle n'a pas encore.
  Widget _champElementExistant() {
    final async = ref.watch(referentielItemsProvider(kEndpointCatalogueElements));
    final modeleId = _modele?.modeleId;
    final options = (async.valueOrNull ?? const <Map<String, dynamic>>[])
        .where((it) => !(it['tarifs'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .any((t) => (t['modeleId'] as num?)?.toInt() == modeleId))
        .map((it) => SelectOption<Object>(
              value: it['id'] as Object,
              label: '${it['libelle'] ?? ''}',
              sousTitre: it['categorieTypeLibelle'] as String? ??
                  'Commun à tous les types',
            ))
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    if (async.isLoading && options.isEmpty) {
      return const LinearProgressIndicator(minHeight: 2);
    }
    return PremiumSelectField<Object>(
      value: _elementExistantId,
      options: options,
      hint: 'Choisir un élément…',
      sheetTitle: 'Élément à ajouter',
      isRequired: true,
      fillColor: AppColors.fieldFill,
      onChanged: (v) => setState(() => _elementExistantId = v),
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
            Icon(icone, size: 15, color: AppColors.label),
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

  // ── Modèle ────────────────────────────────────────────────────────────────

  Widget _champModele() {
    final modele = _modele;
    return GestureDetector(
      onTap: _choisirModele,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(Icons.directions_car_outlined, size: 20, color: AppColors.label),
          const SizedBox(width: 10),
          Expanded(
            child: Text(modele?.libelle ?? 'Choisir un modèle',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: modele == null ? AppColors.hint : AppColors.dark)),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.hint),
        ]),
      ),
    );
  }

  // ── Habillage ─────────────────────────────────────────────────────────────

  Widget _carte({required String titre, required List<Widget> enfants}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(titre.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.hint,
                    letterSpacing: 0.5)),
            const SizedBox(height: 12),
            ...enfants,
          ],
        ),
      );

  Widget _interrupteur(
          String libelle, bool valeur, ValueChanged<bool> onChanged) =>
      Row(children: [
        Expanded(
          child: Text(libelle,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark)),
        ),
        Switch.adaptive(
          value: valeur,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ]);

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
