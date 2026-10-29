import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';
import '../widgets/champ_image_referentiel.dart';

// Fond des champs, aligné sur VehiculeFormPage (au lieu de AppColors.fieldFill,
// une nuance de gris légèrement différente).
Color get _kFieldFill => AppColors.fieldFill;

/// Formulaire générique de création / édition d'une valeur de référentiel.
/// Les champs sont générés à partir du schéma du référentiel (meta-catalogue).
class ReferentielFormPage extends ConsumerStatefulWidget {
  final ReferentielDescriptor descriptor;
  final Map<String, dynamic>? item; // null = création

  const ReferentielFormPage({super.key, required this.descriptor, this.item});

  @override
  ConsumerState<ReferentielFormPage> createState() =>
      _ReferentielFormPageState();
}

class _ReferentielFormPageState extends ConsumerState<ReferentielFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _texts = {};
  final Map<String, Object?> _refs = {}; // champNom -> id sélectionné
  final Map<String, bool> _bools = {};
  final Map<String, String?> _enums =
      {}; // champNom -> valeur (code) sélectionnée
  final Map<String, String?> _images = {}; // champNom -> nom d'objet
  final Map<String, String?> _imagePreview = {}; // champNom -> URL d'aperçu
  bool _saving = false;

  ReferentielDescriptor get d => widget.descriptor;
  bool get _edition => widget.item != null;

  @override
  void initState() {
    super.initState();
    for (final c in d.champsSaisis) {
      switch (c.type) {
        case 'bool':
          _bools[c.nom] = _valBool(c);
          break;
        case 'reference':
          _refs[c.nom] = _valRefId(c);
          break;
        case 'enum':
          _enums[c.nom] = widget.item?[c.nom]?.toString();
          break;
        case 'image':
          _images[c.nom] = widget.item?[c.nom] as String?;
          // Convention : l'URL d'aperçu est renvoyée dans « {nom}Url » (ex. imageUrl).
          _imagePreview[c.nom] = widget.item?['${c.nom}Url'] as String?;
          break;
        default:
          _texts[c.nom] = TextEditingController(text: _valText(c));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Pré-remplissage depuis l'item existant ────────────────────────────────
  String _valText(ChampDescriptor c) => widget.item?[c.nom]?.toString() ?? '';

  bool _valBool(ChampDescriptor c) =>
      widget.item?[c.nom] as bool? ?? (c.nom == 'actif');

  Object? _valRefId(ChampDescriptor c) {
    final item = widget.item;
    if (item == null) return null;
    return _idReference(item, c.nom);
  }

  /// Identifiant porté par [obj] pour le champ référence [nom] : à plat
  /// (`marqueId`) ou imbriqué (`marque: {id}`).
  static Object? _idReference(Map<String, dynamic> obj, String nom) {
    if (obj[nom] != null) return obj[nom]; // ex. typeId à plat
    final nested = nom.endsWith('Id') ? nom.substring(0, nom.length - 2) : nom;
    final sous = obj[nested];
    return sous is Map ? sous['id'] : null;
  }

  /// Champ référence du formulaire dont dépend [c] : celui que portent aussi
  /// les valeurs proposées par [c]. Ex. les modèles portent leur marque — le
  /// choix du modèle se restreint donc à la marque choisie dans le formulaire.
  ChampDescriptor? _champParent(
      ChampDescriptor c, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    for (final p in d.champsSaisis) {
      if (p.type != 'reference' || p.nom == c.nom) continue;
      if (items.any((it) => _idReference(it, p.nom) != null)) return p;
    }
    return null;
  }

  /// Change la valeur d'un champ référence et garde ses voisins cohérents :
  /// choisir un modèle renseigne sa marque, changer de marque vide le modèle
  /// qui n'en relève plus.
  void _changerReference(ChampDescriptor c, Object? valeur) {
    setState(() {
      final avant = _refs[c.nom];
      _refs[c.nom] = valeur;
      if (avant == valeur) return;

      final items = _itemsReference(c);
      final parent = items != null ? _champParent(c, items) : null;
      if (parent != null && valeur != null) {
        final choisi = items!
            .where((it) => it[_refDesc(c)!.idField] == valeur)
            .firstOrNull;
        final idParent = choisi != null ? _idReference(choisi, parent.nom) : null;
        if (idParent != null) _refs[parent.nom] = idParent;
      }

      for (final enfant in d.champsSaisis) {
        if (enfant.type != 'reference' || enfant.nom == c.nom) continue;
        final items = _itemsReference(enfant);
        if (items == null || _champParent(enfant, items)?.nom != c.nom) {
          continue;
        }
        final choisi = items
            .where((it) => it[_refDesc(enfant)!.idField] == _refs[enfant.nom])
            .firstOrNull;
        if (choisi != null &&
            valeur != null &&
            _idReference(choisi, c.nom) != valeur) {
          _refs[enfant.nom] = null;
        }
      }
    });
  }

  ReferentielDescriptor? _refDesc(ChampDescriptor c) {
    final catalogue = ref.read(catalogueProvider).valueOrNull ?? const [];
    return catalogue.where((r) => r.key == c.refKey).firstOrNull;
  }

  List<Map<String, dynamic>>? _itemsReference(ChampDescriptor c) {
    final desc = _refDesc(c);
    if (desc == null) return null;
    return ref.read(referentielItemsProvider(desc.endpoint)).valueOrNull;
  }

  // ── Enregistrement ────────────────────────────────────────────────────────
  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    for (final c in d.champsSaisis.where((c) => c.type == 'reference')) {
      if (c.obligatoire && _refs[c.nom] == null) {
        _toast('Le champ « ${c.label} » est obligatoire.', erreur: true);
        return;
      }
    }
    for (final c in d.champsSaisis.where((c) => c.type == 'enum')) {
      if (c.obligatoire && (_enums[c.nom] == null || _enums[c.nom]!.isEmpty)) {
        _toast('Le champ « ${c.label} » est obligatoire.', erreur: true);
        return;
      }
    }

    final body = <String, dynamic>{};
    for (final c in d.champsSaisis) {
      switch (c.type) {
        case 'bool':
          body[c.nom] = _bools[c.nom];
          break;
        case 'reference':
          body[c.nom] = _refs[c.nom];
          break;
        case 'enum':
          body[c.nom] = _enums[c.nom];
          break;
        case 'number':
          final v = _texts[c.nom]!.text.trim();
          body[c.nom] = v.isEmpty ? null : num.tryParse(v.replaceAll(',', '.'));
          break;
        case 'image':
          body[c.nom] = _images[c.nom];
          break;
        default:
          final v = _texts[c.nom]!.text.trim();
          body[c.nom] = v.isEmpty ? null : v;
      }
    }

    setState(() => _saving = true);
    try {
      final api = ref.read(parametrageApiProvider);
      if (_edition) {
        await api.mettreAJour(
            d.endpoint, widget.item![d.idField] as Object, body);
      } else {
        await api.creer(d.endpoint, body);
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
          title:
              _edition ? 'Modifier — ${d.libelle}' : 'Nouveau — ${d.libelle}'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _enTeteInfo(),
            const SizedBox(height: 18),
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
                  for (final c in d.champsSaisis) ...[
                    const SizedBox(height: 14),
                    _champ(c),
                  ],
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

  // ── En-tête contextuel (identité du référentiel + action en cours) ─────────
  Widget _enTeteInfo() {
    final initiale = d.libelle.isNotEmpty ? d.libelle[0].toUpperCase() : '•';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(initiale,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_edition ? 'Modifier' : 'Nouvel enregistrement',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(
                  d.description.isNotEmpty ? d.description : d.libelle,
                  style:
                      TextStyle(fontSize: 12.5, color: AppColors.label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _champ(ChampDescriptor c) {
    if (!c.editable) return _lectureSeule(c);
    switch (c.type) {
      case 'bool':
        return _champBool(c);
      case 'reference':
        return _champReference(c);
      case 'enum':
        return _champEnum(c);
      case 'image':
        return _champImage(c);
      default:
        return _champTexte(c);
    }
  }

  // ── Champ image (aperçu + choisir/changer/supprimer) ──────────────────────
  Widget _champImage(ChampDescriptor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c),
        ChampImageReferentiel(
          endpoint: d.endpoint,
          titre: c.label,
          previewUrl: _imagePreview[c.nom],
          onChanged: (image, url) => setState(() {
            _images[c.nom] = image;
            _imagePreview[c.nom] = url;
          }),
          onErreur: (message) => _toast(message, erreur: true),
        ),
      ],
    );
  }

  Widget _label(ChampDescriptor c) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: RichText(
          text: TextSpan(
            text: c.label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dark),
            children: c.obligatoire
                ? [
                    TextSpan(
                        text: ' *', style: TextStyle(color: AppColors.error))
                  ]
                : null,
          ),
        ),
      );

  InputDecoration _deco() => InputDecoration(
        filled: true,
        fillColor: _kFieldFill,
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

  Widget _champTexte(ChampDescriptor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c),
        TextFormField(
          controller: _texts[c.nom],
          keyboardType: c.type == 'number'
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: _deco(),
          validator: (v) => c.obligatoire && (v == null || v.trim().isEmpty)
              ? 'Champ obligatoire'
              : null,
        ),
      ],
    );
  }

  Widget _champBool(ChampDescriptor c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(c.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark))),
          Switch.adaptive(
            value: _bools[c.nom] ?? false,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => _bools[c.nom] = v),
          ),
        ],
      ),
    );
  }

  Widget _champReference(ChampDescriptor c) {
    final catalogue = ref.watch(catalogueProvider).valueOrNull ?? const [];
    final refDesc = catalogue.where((r) => r.key == c.refKey).firstOrNull;

    if (refDesc == null) {
      return _champTexte(c); // repli si le référentiel cible est introuvable
    }

    final itemsAsync = ref.watch(referentielItemsProvider(refDesc.endpoint));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c),
        itemsAsync.when(
          loading: () => _selecteurSquelette(),
          error: (_, __) => Text(
              'Impossible de charger « ${refDesc.libelle} ».',
              style: TextStyle(color: AppColors.error, fontSize: 12)),
          data: (items) {
            final titreChamp = refDesc.champTitre?.nom ?? 'nom';
            // Valeurs restreintes au choix du champ parent (ex. modèles de la
            // marque choisie) ; sans choix parent, tout reste proposé.
            final parent = _champParent(c, items);
            final valeurParent = parent != null ? _refs[parent.nom] : null;
            // Restreintes aussi par le filtre déclaré au catalogue (ex. seules
            // les catégories de la sous-catégorie « Maintenances »), en gardant
            // la valeur déjà enregistrée pour ne pas la perdre à l'édition.
            final visibles = items
                .where((it) =>
                    c.accepteReference(it) ||
                    it[refDesc.idField] == _refs[c.nom])
                .where((it) =>
                    valeurParent == null ||
                    _idReference(it, parent!.nom) == valeurParent)
                .toList();
            final options = visibles.map((it) {
              final id = it[refDesc.idField] as Object;
              final label = (it[titreChamp] ?? it['nom'] ?? it['libelle'] ?? id)
                  .toString();
              return SelectOption<Object>(value: id, label: label);
            }).toList();
            return PremiumSelectField<Object>(
              value: _refs[c.nom],
              options: options,
              sheetTitle: c.label,
              hint: c.obligatoire ? 'Choisir…' : 'Tous',
              isRequired: c.obligatoire,
              fillColor: _kFieldFill,
              onChanged: (v) => _changerReference(c, v),
            );
          },
        ),
      ],
    );
  }

  Widget _champEnum(ChampDescriptor c) {
    final options =
        c.options
            .map((o) => SelectOption<String>(value: o, label: c.libelleDe(o)))
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c),
        PremiumSelectField<String>(
          value: _enums[c.nom],
          options: options,
          sheetTitle: c.label,
          isRequired: c.obligatoire,
          searchable: false,
          fillColor: _kFieldFill,
          onChanged: (v) => setState(() => _enums[c.nom] = v),
        ),
      ],
    );
  }

  /// Placeholder pendant le chargement des valeurs d'un référentiel lié.
  Widget _selecteurSquelette() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary)),
          const SizedBox(width: 12),
          Text('Chargement…',
              style: TextStyle(color: AppColors.hint, fontSize: 14)),
        ]),
      );

  Widget _lectureSeule(ChampDescriptor c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_valText(c).isEmpty ? '—' : _valText(c),
              style: TextStyle(color: AppColors.label)),
        ),
      ],
    );
  }
}
