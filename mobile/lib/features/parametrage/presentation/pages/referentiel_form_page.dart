import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/image_viewer.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';

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
  final Map<String, String?> _images = {}; // champNom -> nom d'objet
  final Map<String, String?> _imagePreview = {}; // champNom -> URL d'aperçu
  final Set<String> _uploading = {};
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
    if (item[c.nom] != null) return item[c.nom]; // ex. typeId à plat
    final nested = c.nom.endsWith('Id')
        ? c.nom.substring(0, c.nom.length - 2)
        : c.nom;
    final obj = item[nested];
    return obj is Map ? obj['id'] : null;
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

    final body = <String, dynamic>{};
    for (final c in d.champsSaisis) {
      switch (c.type) {
        case 'bool':
          body[c.nom] = _bools[c.nom];
          break;
        case 'reference':
          body[c.nom] = _refs[c.nom];
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
          title: _edition ? 'Modifier — ${d.libelle}' : 'Nouveau — ${d.libelle}'),
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
        decoration: const BoxDecoration(
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
            decoration: const BoxDecoration(
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
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(
                  d.description.isNotEmpty ? d.description : d.libelle,
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.label),
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
      case 'image':
        return _champImage(c);
      default:
        return _champTexte(c);
    }
  }

  // ── Champ image (aperçu + choisir/changer/supprimer) ──────────────────────
  Future<void> _choisirImage(String nom) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _uploading.add(nom));
    try {
      final bytes = await picked.readAsBytes();
      final res = await ref
          .read(parametrageApiProvider)
          .uploaderImage(d.endpoint, bytes, picked.name);
      if (!mounted) return;
      setState(() {
        _images[nom] = res.image;
        _imagePreview[nom] = res.url;
      });
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _uploading.remove(nom));
    }
  }

  Widget _champImage(ChampDescriptor c) {
    final preview = _imagePreview[c.nom];
    final uploading = _uploading.contains(c.nom);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(c),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: uploading
              ? _imageUploading()
              : preview == null
                  ? _imageDropzone(c)
                  : _imageRempli(c, preview),
        ),
      ],
    );
  }

  /// État vide : zone d'ajout élégante, entièrement cliquable.
  Widget _imageDropzone(ChampDescriptor c) {
    return GestureDetector(
      onTap: () => _choisirImage(c.nom),
      child: Container(
        height: 172,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryTint, AppColors.fieldFill],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.add_photo_alternate_rounded,
                  size: 27, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            const Text('Ajouter une image',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark)),
            const SizedBox(height: 3),
            const Text('JPG ou PNG · appuyez pour parcourir',
                style: TextStyle(fontSize: 12, color: AppColors.label)),
          ],
        ),
      ),
    );
  }

  /// Image présente : plein cadre, ombre douce, actions flottantes superposées.
  Widget _imageRempli(ChampDescriptor c, String preview) {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.dark.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onTap: () => showImageViewer(context, preview, titre: c.label),
              child: Image.network(
                preview,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.fieldFill,
                    child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.fieldFill,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: AppColors.hint, size: 30),
                        SizedBox(height: 6),
                        Text('Image indisponible',
                            style:
                                TextStyle(color: AppColors.hint, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Voile bas + indice « agrandir ».
            IgnorePointer(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 26, 14, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.dark.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.zoom_out_map_rounded,
                          size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Appuyez pour agrandir',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
            // Actions flottantes givrées.
            Positioned(
              top: 10,
              right: 10,
              child: Row(
                children: [
                  _actionFlottante(
                    icon: Icons.swap_horiz_rounded,
                    tooltip: 'Changer',
                    onTap: () => _choisirImage(c.nom),
                  ),
                  const SizedBox(width: 8),
                  _actionFlottante(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Supprimer',
                    couleur: AppColors.error,
                    onTap: () => setState(() {
                      _images[c.nom] = null;
                      _imagePreview[c.nom] = null;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Téléversement en cours : cadre neutre avec indicateur centré.
  Widget _imageUploading() {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            SizedBox(height: 12),
            Text('Téléversement…',
                style: TextStyle(color: AppColors.label, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  /// Bouton circulaire givré posé sur l'image (changer / supprimer).
  Widget _actionFlottante({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color couleur = AppColors.dark,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: AppColors.dark.withValues(alpha: 0.3),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(icon, size: 19, color: couleur),
          ),
        ),
      ),
    );
  }

  Widget _label(ChampDescriptor c) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: RichText(
          text: TextSpan(
            text: c.label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark),
            children: c.obligatoire
                ? const [
                    TextSpan(text: ' *', style: TextStyle(color: AppColors.error))
                  ]
                : null,
          ),
        ),
      );

  InputDecoration _deco() => InputDecoration(
        filled: true,
        fillColor: AppColors.fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
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
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
              child: Text(c.label,
                  style: const TextStyle(
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
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (_, __) => Text('Impossible de charger « ${refDesc.libelle} ».',
              style: const TextStyle(color: AppColors.error, fontSize: 12)),
          data: (items) {
            final titreChamp = refDesc.champTitre?.nom ?? 'nom';
            return DropdownButtonFormField<Object>(
              initialValue: _refs[c.nom],
              isExpanded: true,
              decoration: _deco(),
              hint: const Text('Choisir…', style: TextStyle(color: AppColors.hint)),
              items: items.map((it) {
                final id = it[refDesc.idField] as Object;
                final label =
                    (it[titreChamp] ?? it['nom'] ?? it['libelle'] ?? id).toString();
                return DropdownMenuItem<Object>(value: id, child: Text(label));
              }).toList(),
              onChanged: (v) => setState(() => _refs[c.nom] = v),
              validator: (v) =>
                  c.obligatoire && v == null ? 'Champ obligatoire' : null,
            );
          },
        ),
      ],
    );
  }

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
              style: const TextStyle(color: AppColors.label)),
        ),
      ],
    );
  }
}
