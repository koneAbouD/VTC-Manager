import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_source_bottom_sheet.dart';
import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../../domain/enums/genre.dart';
import '../../domain/enums/type_chauffeur.dart';
import '../providers/chauffeur_provider.dart';
import '../providers/chauffeur_state.dart';
import '../providers/documents_by_chauffeur_provider.dart'
    show
        DocumentChauffeurLocal,
        docChauffeurApiClientProvider,
        documentsByChauffeurIdProvider;
import '../providers/type_document_chauffeur_provider.dart';
import '../../../vehicule/presentation/providers/type_document_provider.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';

const _kPrimary = Color(0xFF3B5BDB);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint = Color(0xFF9AA0AE);
const _kLabel = Color(0xFF6B7280);
const _kBorder = Color(0xFFE3E6EE);
const _kDark  = Color(0xFF1A1A2E);

// ── Toast helpers ─────────────────────────────────────────────────────────────

enum _ToastType { success, error, warning, info }

void _appToast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.success,
  Duration? duration,
}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
    _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ??
          (type == _ToastType.error || type == _ToastType.warning
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2)),
    ));
}

/// Banner affiché EN HAUT du formulaire document (bottom sheet).
/// Géré par [_AddDocumentSheetState._showInline].
class _InlineToastBanner extends StatelessWidget {
  final String? message;
  final _ToastType type;
  const _InlineToastBanner({super.key, this.message, this.type = _ToastType.error});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final (Color bg, IconData icon) = switch (type) {
      _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
      _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
      _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
      _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
    };
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message!,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
/// Page d'ajout / modification d'un chauffeur — flow en 2 étapes.
/// ─────────────────────────────────────────────────────────────────────────
class ChauffeurFormPage extends ConsumerStatefulWidget {
  final Chauffeur? initial;
  const ChauffeurFormPage({super.key, this.initial});

  @override
  ConsumerState<ChauffeurFormPage> createState() => _ChauffeurFormPageState();
}

class _ChauffeurFormPageState extends ConsumerState<ChauffeurFormPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  bool _loading = false;

  // ── Controllers ────────────────────────────────────────────────────────
  late final TextEditingController _nom;
  late final TextEditingController _prenom;
  late final TextEditingController _email;
  late final TextEditingController _telephone;

  // ── Form keys ──────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  // ── Selections étape 1 ─────────────────────────────────────────────────
  _Country _indicatif = _kCountries.firstWhere((c) => c.iso == 'CI');
  Genre? _genre;
  TypeChauffeur? _type;
  XFile? _photo;

  // ── Documents en attente ───────────────────────────────────────────────
  final List<_PendingDocument> _pendingDocuments = [];

  // ── Suppression de la photo existante ─────────────────────────────────
  bool _photoDeleted = false;

  // ── Bytes de la photo d'identité (document) utilisée comme fallback ───
  Future<Uint8List>? _photoDocBytesFuture;

  // ── Snapshot initial pour détecter les modifications ───────────────────
  late final String _initNom;
  late final String _initPrenom;
  late final String _initEmail;
  late final String _initTelephone;
  late final Genre? _initGenre;
  late final TypeChauffeur? _initType;

  bool get _isEditing => widget.initial != null;

  bool get _hasChanges =>
      _nom.text != _initNom ||
      _prenom.text != _initPrenom ||
      _email.text != _initEmail ||
      _telephone.text != _initTelephone ||
      _genre != _initGenre ||
      _type != _initType ||
      _photo != null ||
      _photoDeleted ||
      _pendingDocuments.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _tabCtrl = TabController(length: 2, vsync: this);
    _nom = TextEditingController(text: c?.nom ?? '');
    _prenom = TextEditingController(text: c?.prenom ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _telephone = TextEditingController(text: _stripIndicatif(c?.telephone));
    _genre = c?.genre;
    _type = c?.type;

    // Snapshot après hydratation
    _initNom = _nom.text;
    _initPrenom = _prenom.text;
    _initEmail = _email.text;
    _initTelephone = _telephone.text;
    _initGenre = _genre;
    _initType = _type;

    _nom.addListener(_onChanged);
    _prenom.addListener(_onChanged);
    _email.addListener(_onChanged);
    _telephone.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  String _stripIndicatif(String? phone) {
    if (phone == null) return '';
    final normalized = phone.trim();
    if (normalized.isEmpty) return '';

    // Cas 1 : stocké au format E.164 « +225 14374838 » ou « +22514374838 ».
    for (final c in _kCountries) {
      if (normalized.startsWith(c.dial)) {
        _indicatif = c;
        return normalized.substring(c.dial.length).trim();
      }
    }

    // Cas 2 : ancien format sans le « + » (ex. « 22514374838 » en BDD).
    // On cherche un indicatif connu (sans le signe plus) qui préfixe le
    // numéro et on tombe sur le local.
    for (final c in _kCountries) {
      final dialDigits = c.dial.substring(1); // retire le « + »
      if (dialDigits.isNotEmpty && normalized.startsWith(dialDigits)) {
        _indicatif = c;
        return normalized.substring(dialDigits.length).trim();
      }
    }

    return normalized;
  }

  @override
  void dispose() {
    _nom.removeListener(_onChanged);
    _prenom.removeListener(_onChanged);
    _email.removeListener(_onChanged);
    _telephone.removeListener(_onChanged);
    _tabCtrl.dispose();
    _nom.dispose();
    _prenom.dispose();
    _email.dispose();
    _telephone.dispose();
    super.dispose();
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _tabCtrl.animateTo(0);
      return;
    }
    if (_genre == null) {
      _tabCtrl.animateTo(0);
      _toast('Veuillez sélectionner un genre.', type: _ToastType.error);
      return;
    }
    if (_type == null) {
      _tabCtrl.animateTo(0);
      _toast('Veuillez sélectionner un type de chauffeur.', type: _ToastType.error);
      return;
    }
    _PendingDocument? permisDoc;
    if (!_isEditing) {
      permisDoc = _pendingDocuments
          .where((d) => d.typeNom.toLowerCase().contains('permis'))
          .firstOrNull;
      if (permisDoc == null) {
        _tabCtrl.animateTo(1);
        _toast('Veuillez ajouter un permis de conduire.', type: _ToastType.error);
        return;
      }
    }
    setState(() => _loading = true);

    final fullPhone = _telephone.text.trim().isEmpty
        ? null
        : '${_indicatif.dial} ${_telephone.text.trim()}';

    final chauffeur = Chauffeur(
      id: widget.initial?.id,
      nom: _nom.text.trim(),
      prenom: _prenom.text.trim(),
      genre: _genre ?? widget.initial?.genre,
      type: _type ?? widget.initial?.type,
      dateNaissance: widget.initial?.dateNaissance,
      photoUrl: widget.initial?.photoUrl,
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      telephone: fullPhone,
      adresse: widget.initial?.adresse,
      statut: widget.initial?.statut ?? ChauffeurStatus.actif,
      dateEmbauche: widget.initial?.dateEmbauche,
      geolocalisation: widget.initial?.geolocalisation,
      vehiculeId: widget.initial?.vehiculeId,
      vehiculeNom: widget.initial?.vehiculeNom,
    );

    final notifier = ref.read(chauffeurNotifierProvider.notifier);
    String? error;

    if (_isEditing) {
      // Si l'utilisateur a choisi une nouvelle photo depuis l'écran
      // d'édition, on l'envoie au backend en multipart. Sinon, seule la
      // partie `data` JSON est mise à jour.
      final photoBytes = _photo != null ? await _photo!.readAsBytes() : null;
      error = await notifier.updateChauffeur(
        widget.initial!.id!,
        chauffeur,
        photoBytes: photoBytes,
        photoFilename: _photo?.name ?? 'photo.jpg',
        deletePhoto: _photoDeleted,
      );
    } else {
      final photoBytes = _photo != null ? await _photo!.readAsBytes() : null;
      error = await notifier.createChauffeur(
        chauffeur,
        permisBytes: permisDoc!.bytes,
        permisFilename: permisDoc.filename,
        photoBytes: photoBytes,
        photoFilename: _photo?.name ?? 'photo.jpg',
        numeroPermis: permisDoc.reference,
        typesPermis: permisDoc.typesPermis,
        dateEmissionPermis: permisDoc.dateEmission,
        dateExpirationPermis:
            permisDoc.permanent ? null : permisDoc.dateExpiration,
      );
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      _toast(error, type: _ToastType.error);
      return;
    }

    // ── Succès ──────────────────────────────────────────────────────────────
    if (_isEditing) {
      final id = widget.initial!.id;
      if (id != null) {
        // 1. Invalider le provider detail pour refetch immédiat des données.
        ref.invalidate(chauffeurByIdProvider(id));

        // 2. Casser le cache image uniquement lors d'un upload (pas d'une suppression :
        //    le re-fetch du provider donnera hasPhoto=false, aucun chargement photo).
        if (_photo != null) {
          ref.read(chauffeurPhotoVersionProvider.notifier).update((m) {
            final updated = Map<int, int>.from(m);
            updated[id] = (updated[id] ?? 0) + 1;
            return updated;
          });
        }
      }
    }

    // ── Upload des pièces justificatives en attente (mode création) ────────
    if (!_isEditing && _pendingDocuments.isNotEmpty) {
      final state = ref.read(chauffeurNotifierProvider);
      int? createdId;
      if (state is ChauffeurLoaded && state.chauffeurs.isNotEmpty) {
        final match = state.chauffeurs
            .where((c) =>
                c.nom == chauffeur.nom && c.prenom == chauffeur.prenom)
            .lastOrNull;
        createdId = match?.id;
      }
      if (createdId != null) {
        final ds = ref.read(chauffeurDatasourceProvider);
        for (final doc in _pendingDocuments) {
          if (doc == permisDoc) continue;
          try {
            await ds.uploadDocumentChauffeur(
              chauffeurId: createdId,
              typeDocumentId: doc.typeDocumentId,
              bytes: doc.bytes,
              filename: doc.filename,
              reference: doc.reference,
              dateEmission:
                  doc.dateEmission?.toIso8601String().substring(0, 10),
              dateExpiration: doc.permanent
                  ? null
                  : doc.dateExpiration?.toIso8601String().substring(0, 10),
              categorie:
                  doc.typesPermis.isEmpty ? null : doc.typesPermis,
              permanent: doc.permanent,
            );
          } catch (_) {}
        }
      }
    }

    if (!mounted) return;
    if (_isEditing) {
      _toast('Chauffeur modifié avec succès.');
      Navigator.pop(context);
    } else {
      _showChauffeurCreatedDialog();
    }
  }

  void _openPhotoViewer() {
    final chauffeurId = widget.initial?.id;

    final photoBase64 = widget.initial?.photoBase64;
    final Widget photoWidget = _photo != null
        ? _XFileImage(file: _photo!, fit: BoxFit.contain)
        : (photoBase64 != null
            ? Image.memory(base64Decode(photoBase64), fit: BoxFit.contain)
            : _AuthenticatedNetworkImage(
                imageUrl: '${ApiConfig.baseUrl}/chauffeurs/$chauffeurId/photo',
                fit: BoxFit.contain,
              ));

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => _ChauffeurPhotoViewer(
        photo: photoWidget,
        onReplace: () {
          Navigator.pop(context);
          _pickPhoto();
        },
        onRemove: _photo != null
            ? () {
                Navigator.pop(context);
                setState(() => _photo = null);
              }
            : () {
                Navigator.pop(context);
                setState(() => _photoDeleted = true);
              },
      ),
    );
  }

  void _toast(String msg, {_ToastType type = _ToastType.success}) =>
      _appToast(context, msg, type: type);

  void _showChauffeurCreatedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  color: _kPrimary, size: 40),
            ),
            const SizedBox(height: 18),
            const Text(
              'Chauffeur créé !',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le chauffeur a bien été ajouté à la flotte.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Retour à la liste',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image picker ───────────────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    try {
      final picked = await pickImageFromSource(context);
      if (picked != null) setState(() => _photo = picked);
    } catch (e) {
      _toast('Impossible de récupérer l\'image : $e', type: _ToastType.error);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(typesDocChauffeurProvider);

    final existingDocsAsync = _isEditing && widget.initial?.id != null
        ? ref.watch(documentsByChauffeurIdProvider(widget.initial!.id!))
        : const AsyncValue<List<DocumentChauffeurLocal>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppHeader(
        title: _isEditing ? 'Modifier le chauffeur' : 'Nouveau chauffeur',
        action: !_hasChanges
            ? null
            : AppHeaderAction(
                icon: Icons.check_rounded,
                loading: _loading,
                onTap: _save,
              ),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildStep1(),
                  _buildDocumentsTab(existingDocsAsync: existingDocsAsync),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabCtrl,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: const Color(0xFF1A1A2E),
          unselectedLabelColor: const Color(0xFF9AA0AE),
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.all(4),
          tabs: const [
            Tab(text: 'Informations'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // TAB 1 — Informations de base
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildCircularPhotoSlot() {
    final hasNew = _photo != null;
    final chauffeurId = widget.initial?.id;
    final hasExisting = !_photoDeleted &&
        chauffeurId != null &&
        (widget.initial?.photoUrl?.isNotEmpty ?? false);

    DocumentChauffeurLocal? photoDoc;
    if (!hasNew && !hasExisting && !_photoDeleted && chauffeurId != null) {
      final allDocs = ref.watch(documentsByChauffeurIdProvider(chauffeurId));
      photoDoc = allDocs.valueOrNull
          ?.where((d) =>
              d.typeNom?.toLowerCase() == "photo d'identité" &&
              d.fichierUrl != null)
          .firstOrNull;
    }

    Widget avatarContent;
    if (hasNew) {
      avatarContent = FutureBuilder<Uint8List>(
        future: _photo!.readAsBytes(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return Image.memory(snap.data!, fit: BoxFit.cover);
        },
      );
    } else if (hasExisting) {
      final photoBase64 = widget.initial?.photoBase64;
      avatarContent = photoBase64 != null
          ? Image.memory(base64Decode(photoBase64), fit: BoxFit.cover)
          : _RemoteChauffeurPhoto(chauffeurId: chauffeurId);
    } else if (photoDoc != null) {
      _photoDocBytesFuture ??=
          ref.read(docChauffeurApiClientProvider).getBytes(photoDoc.fichierUrl!);
      avatarContent = FutureBuilder<Uint8List>(
        future: _photoDocBytesFuture,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return Image.memory(snap.data!, fit: BoxFit.cover);
        },
      );
    } else {
      avatarContent = Container(
        color: const Color(0xFFEEF2FF),
        child: const Icon(Icons.person_rounded, color: Color(0xFFBBC4E8), size: 52),
      );
    }

    final hasPhoto = hasNew || hasExisting || photoDoc != null;

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: hasPhoto ? _openPhotoViewer : _pickPhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBorder, width: 2),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: avatarContent,
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasPhoto ? 'Appuyez pour voir ou modifier' : 'Appuyez pour ajouter une photo',
            style: const TextStyle(fontSize: 12, color: _kHint),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        children: [
          // ── Carte Identité ──────────────────────────────────────────────
          _ChauffeurFormCard(
            icon: Icons.person_outline_rounded,
            accent: _kPrimary,
            title: 'Identité',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ChauffeurLabeledField(
                        label: 'Nom',
                        isRequired: true,
                        child: _PillField(
                          controller: _nom,
                          hint: 'Nom de famille',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requis' : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ChauffeurLabeledField(
                        label: 'Prénom',
                        isRequired: true,
                        child: _PillField(
                          controller: _prenom,
                          hint: 'Prénom',
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requis' : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _ChauffeurLabeledField(
                        label: 'Genre',
                        isRequired: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kFieldFill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _genre?.backend,
                              isExpanded: true,
                              hint: const Text('Genre',
                                  style: TextStyle(color: _kHint, fontSize: 15)),
                              borderRadius: BorderRadius.circular(14),
                              menuMaxHeight: 320,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 18, color: _kHint),
                              onChanged: (v) => setState(() =>
                                  _genre = v == null ? null : Genre.fromJson(v)),
                              items: Genre.values
                                  .map((g) => DropdownMenuItem<String?>(
                                        value: g.backend,
                                        child: Text(g.label,
                                            style: const TextStyle(fontSize: 15)),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ChauffeurLabeledField(
                        label: 'Type',
                        isRequired: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kFieldFill,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _type?.backend,
                              isExpanded: true,
                              hint: const Text('Type',
                                  style: TextStyle(color: _kHint, fontSize: 15)),
                              borderRadius: BorderRadius.circular(14),
                              menuMaxHeight: 320,
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  size: 18, color: _kHint),
                              onChanged: (v) => setState(() =>
                                  _type = v == null
                                      ? null
                                      : TypeChauffeur.fromJson(v)),
                              items: TypeChauffeur.values
                                  .map((t) => DropdownMenuItem<String?>(
                                        value: t.backend,
                                        child: Text(t.label,
                                            style: const TextStyle(fontSize: 15)),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Carte Coordonnées ───────────────────────────────────────────
          _ChauffeurFormCard(
            icon: Icons.contact_mail_outlined,
            accent: const Color(0xFF0CA678),
            title: 'Coordonnées',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChauffeurLabeledField(
                  label: 'Adresse email',
                  child: _PillField(
                    controller: _email,
                    hint: 'exemple@email.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(v.trim());
                      return ok ? null : 'Email invalide';
                    },
                  ),
                ),
                const SizedBox(height: 14),
                _ChauffeurLabeledField(
                  label: 'Téléphone',
                  child: _PhonePill(
                    country: _indicatif,
                    controller: _telephone,
                    onCountryTap: () async {
                      final picked = await _showCountryPicker(context);
                      if (picked != null) setState(() => _indicatif = picked);
                    },
                  ),
                ),
              ],
            ),
          ),

          // ── Carte Photo ─────────────────────────────────────────────────
          _ChauffeurFormCard(
            icon: Icons.camera_alt_outlined,
            accent: const Color(0xFF7950F2),
            title: 'Photo du chauffeur',
            child: _buildCircularPhotoSlot(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────
  // TAB 2 — Documents (permis + pièces justificatives)
  // ─────────────────────────────────────────────────────────────────────
  Widget _buildDocumentsTab({
    required AsyncValue<List<DocumentChauffeurLocal>> existingDocsAsync,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        // ── Section Documents enregistrées (permis inclus) ────────────────
        const _ChauffeurSectionTitle('Documents enregistrées'),
        const SizedBox(height: 10),
        if (_isEditing) ...[
          existingDocsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Impossible de charger les documents.',
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
            data: (docs) {
              // Filtrer seulement la photo d'identité (le permis est maintenant un doc)
              final filtered = docs.where((d) {
                final nom = d.typeNom?.toLowerCase() ?? '';
                if (nom == "photo d'identité") return false;
                return true;
              }).toList();
              if (filtered.isEmpty && _pendingDocuments.isEmpty) {
                return _EmptyDocState();
              }
              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Aucune pièce enregistrée.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                );
              }
              return Column(
                children: filtered
                    .map((doc) => _ExistingDocCard(
                          doc: doc,
                          onDelete: () => _deleteExistingDocument(doc.id),
                          onTap: () => _showExistingDocDetail(doc),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
        if (_pendingDocuments.isNotEmpty) ...[
          ..._pendingDocuments.asMap().entries.map(
                (e) => _PendingDocCard(
                  doc: e.value,
                  onRemove: () =>
                      setState(() => _pendingDocuments.removeAt(e.key)),
                  onTap: () => _showPendingDocDetail(e.key, e.value),
                ),
              ),
          const SizedBox(height: 8),
        ],
        if (!_isEditing && _pendingDocuments.isEmpty) ...[
          _EmptyDocState(),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: _showAddDocumentSheet,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter une pièce'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPrimary,
            side: const BorderSide(color: _kPrimary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            minimumSize: const Size(double.infinity, 0),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ── Méthodes de gestion des documents ─────────────────────────────────────

  Future<void> _showAddDocumentSheet() async {
    final types =
        ref.read(typesDocChauffeurProvider).valueOrNull ?? [];
    if (types.isEmpty) {
      _toast('Aucun type de document disponible.', type: _ToastType.warning);
      return;
    }
    final result = await showModalBottomSheet<_PendingDocument>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddDocumentSheet(types: types),
    );
    if (result == null || !mounted) return;
    final chauffeurId = widget.initial?.id;
    if (_isEditing && chauffeurId != null) {
      await _uploadDocumentNow(result, chauffeurId);
    } else {
      setState(() => _pendingDocuments.add(result));
    }
  }

  Future<void> _uploadDocumentNow(_PendingDocument doc, int chauffeurId) async {
    final ds = ref.read(chauffeurDatasourceProvider);
    setState(() => _loading = true);
    try {
      await ds.uploadDocumentChauffeur(
        chauffeurId: chauffeurId,
        typeDocumentId: doc.typeDocumentId,
        bytes: doc.bytes,
        filename: doc.filename,
        reference: doc.reference,
        dateEmission:
            doc.dateEmission?.toIso8601String().substring(0, 10),
        dateExpiration: doc.permanent
            ? null
            : doc.dateExpiration?.toIso8601String().substring(0, 10),
        categorie: doc.typesPermis.isEmpty ? null : doc.typesPermis,
        permanent: doc.permanent,
      );
      if (mounted) {
        ref.invalidate(documentsByChauffeurIdProvider(chauffeurId));
        _toast('Document ajouté avec succès.');
      }
    } catch (_) {
      if (mounted) {
        _toast("Impossible d'ajouter ce document, réessayez.", type: _ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteExistingDocument(int docId) async {
    String? motif;
    final motifCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline,
                    color: Color(0xFFE03131), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Supprimer le document',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Le document sera définitivement supprimé. Cette action est irréversible.',
                style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade600,
                    height: 1.4),
              ),
              const SizedBox(height: 16),
              const Text(
                'Motif *',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kLabel),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: motifCtrl,
                autofocus: true,
                maxLines: 2,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ex : Document expiré, remplacé…',
                  hintStyle:
                      const TextStyle(color: _kHint, fontSize: 14),
                  filled: true,
                  fillColor: _kFieldFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                side: const BorderSide(color: _kBorder),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Annuler',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              onPressed: motifCtrl.text.trim().isEmpty
                  ? null
                  : () {
                      motif = motifCtrl.text.trim();
                      Navigator.pop(ctx);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE03131),
                disabledBackgroundColor:
                    const Color(0xFFE03131).withValues(alpha: 0.35),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Supprimer',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
    motifCtrl.dispose();
    if (motif == null || !mounted) return;
    final ds = ref.read(chauffeurDatasourceProvider);
    try {
      await ds.archiverDocumentChauffeur(docId, motif!);
      if (mounted) {
        ref.invalidate(
            documentsByChauffeurIdProvider(widget.initial!.id!));
        _toast('Document archivé.');
      }
    } catch (_) {
      if (mounted) {
        _toast('Impossible de supprimer ce document.', type: _ToastType.error);
      }
    }
  }

  Future<void> _showPendingDocDetail(
      int index, _PendingDocument doc) async {
    final types =
        ref.read(typesDocChauffeurProvider).valueOrNull ?? [];
    final result = await showModalBottomSheet<_PendingDocument>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddDocumentSheet(types: types, initialDoc: doc),
    );
    if (result == null || !mounted) return;
    final chauffeurId = widget.initial?.id;
    if (_isEditing && chauffeurId != null) {
      setState(() => _pendingDocuments.removeAt(index));
      await _uploadDocumentNow(result, chauffeurId);
    } else {
      setState(() => _pendingDocuments[index] = result);
    }
  }

  Future<void> _showExistingDocDetail(DocumentChauffeurLocal doc) async {
    final types =
        ref.read(typesDocChauffeurProvider).valueOrNull ?? [];

    // Pré-charger les bytes du fichier existant pour les afficher dans le sheet.
    Uint8List? existingBytes;
    final fileUrl = doc.fichierUrl;
    if (fileUrl != null && fileUrl.isNotEmpty) {
      try {
        final client = ref.read(docChauffeurApiClientProvider);
        existingBytes = await client.getBytes(fileUrl);
      } catch (_) {
        // Impossible de pré-charger ; l'utilisateur devra re-joindre le fichier.
      }
    }

    if (!mounted) return;
    final result = await showModalBottomSheet<_PendingDocument>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddDocumentSheet(
        types: types,
        existingDoc: doc,
        existingBytes: existingBytes,
      ),
    );
    if (result == null || !mounted) return;
    final chauffeurId = widget.initial!.id!;
    setState(() => _loading = true);
    try {
      final ds = ref.read(chauffeurDatasourceProvider);
      await ds.uploadDocumentChauffeur(
        chauffeurId: chauffeurId,
        typeDocumentId: result.typeDocumentId,
        bytes: result.bytes,
        filename: result.filename,
        reference: result.reference,
        dateEmission:
            result.dateEmission?.toIso8601String().substring(0, 10),
        dateExpiration: result.permanent
            ? null
            : result.dateExpiration?.toIso8601String().substring(0, 10),
        categorie: result.typesPermis.isEmpty ? null : result.typesPermis,
        permanent: result.permanent,
      );
      await ds.deleteDocument(doc.id);
      if (mounted) {
        ref.invalidate(documentsByChauffeurIdProvider(chauffeurId));
        _toast('Document mis à jour.');
      }
    } catch (_) {
      if (mounted) {
        _toast('Impossible de mettre à jour ce document.', type: _ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Carte de section formulaire ─────────────────────────────────────────
class _ChauffeurFormCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;

  const _ChauffeurFormCard({
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
          Row(
            children: [
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
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ─── Titre de section (style VehiculeFormPage) ────────────────────────────
class _ChauffeurSectionTitle extends StatelessWidget {
  final String text;
  const _ChauffeurSectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1A2E),
        letterSpacing: 0.2,
      ),
    );
  }
}


// ═════════════════════════════════════════════════════════════════════════
//  WIDGETS COMMUNS
// ═════════════════════════════════════════════════════════════════════════

class _PillField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  const _PillField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kHint, fontSize: 15),
        filled: true,
        fillColor: _kFieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(color: _kPrimary, width: 1.2),
        errorBorder: _border(color: Colors.red),
        focusedErrorBorder: _border(color: Colors.red, width: 1.2),
      ),
    );
  }

  OutlineInputBorder _border({Color? color, double width = 0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: color == null
            ? BorderSide.none
            : BorderSide(color: color, width: width),
      );
}

/// Champ téléphone (pill) avec sélecteur d'indicatif + icône téléphone.
class _PhonePill extends StatelessWidget {
  final _Country country;
  final TextEditingController controller;
  final VoidCallback onCountryTap;
  const _PhonePill({
    required this.country,
    required this.controller,
    required this.onCountryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          InkWell(
            onTap: onCountryTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    country.dial,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down,
                      size: 18, color: _kHint),
                ],
              ),
            ),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]')),
              ],
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              decoration: const InputDecoration(
                hintText: '07 00 00 00 00',
                hintStyle: TextStyle(color: _kHint, fontSize: 15),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 18),
                border: InputBorder.none,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.phone_iphone_outlined, color: _kHint, size: 22),
          ),
        ],
      ),
    );
  }
}

/// Charge la photo actuelle d'un chauffeur via `/chauffeurs/{id}/photo`
/// avec le Bearer token (miroir du comportement de l'écran de détail).
class _RemoteChauffeurPhoto extends StatefulWidget {
  final int chauffeurId;
  const _RemoteChauffeurPhoto({required this.chauffeurId});

  @override
  State<_RemoteChauffeurPhoto> createState() => _RemoteChauffeurPhotoState();
}

class _RemoteChauffeurPhotoState extends State<_RemoteChauffeurPhoto> {
  Future<Map<String, String>?>? _headersFuture;

  @override
  void initState() {
    super.initState();
    _headersFuture = _loadAuthHeaders();
  }

  Widget _fallback() => Container(
        color: const Color(0xFFF2F3F5),
        child: const Center(
          child: Icon(Icons.person_outline, color: _kBorder, size: 36),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: _headersFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return _fallback();
        final headers = snap.data;
        if (headers == null) return _fallback();
        return Image.network(
          '${ApiConfig.baseUrl}/chauffeurs/${widget.chauffeurId}/photo',
          fit: BoxFit.cover,
          headers: headers,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _fallback(),
        );
      },
    );
  }
}

/// Affiche un [XFile] via ses bytes (compatible Flutter Web).
class _XFileImage extends StatelessWidget {
  final XFile file;
  final BoxFit fit;

  const _XFileImage({
    required this.file,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: file.readAsBytes(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            color: const Color(0xFFF2F3F5),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return Container(
            color: const Color(0xFFF2F3F5),
            child: const Icon(Icons.broken_image_outlined,
                color: _kBorder, size: 28),
          );
        }
        return Image.memory(snap.data!, fit: fit);
      },
    );
  }
}

Future<Map<String, String>?> _loadAuthHeaders() async {
  final token = await const SecureStorage().getAccessToken();
  if (token == null || token.isEmpty) return null;
  return {'Authorization': 'Bearer $token'};
}

class _AuthenticatedNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;

  const _AuthenticatedNetworkImage({
    required this.imageUrl,
    this.fit = BoxFit.cover,
  });

  @override
  State<_AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState
    extends State<_AuthenticatedNetworkImage> {
  Future<Map<String, String>?>? _headersFuture;

  @override
  void initState() {
    super.initState();
    _headersFuture = _loadAuthHeaders();
  }

  Widget _fallback() => Container(
        color: const Color(0xFF0F172A),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined,
            color: Colors.white38, size: 44),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>?>(
      future: _headersFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
              strokeWidth: 2,
            ),
          );
        }
        return Image.network(
          widget.imageUrl,
          fit: widget.fit,
          headers: snap.data,
          errorBuilder: (_, __, ___) => _fallback(),
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                ),
        );
      },
    );
  }
}

class _ChauffeurFieldLabel extends StatelessWidget {
  final String text;
  const _ChauffeurFieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _kLabel,
      ),
    );
  }
}

class _ChauffeurLabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isRequired;
  const _ChauffeurLabeledField({
    required this.label,
    required this.child,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        isRequired
            ? RichText(
                text: TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kLabel,
                  ),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            : _ChauffeurFieldLabel(label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}




class _ChauffeurPhotoViewer extends StatelessWidget {
  final Widget photo;
  final VoidCallback onReplace;
  final VoidCallback? onRemove;

  const _ChauffeurPhotoViewer({
    required this.photo,
    required this.onReplace,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    const Text(
                      'Photo du chauffeur',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              SizedBox(
                height: 320,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(child: photo),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReplace,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Remplacer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    if (onRemove != null) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Supprimer'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB91C1C),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  COUNTRY PICKER (bottom-sheet)
// ═════════════════════════════════════════════════════════════════════════

Future<_Country?> _showCountryPicker(BuildContext context) {
  return showModalBottomSheet<_Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CountryPickerSheet(),
  );
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet();

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';
  late final List<_Country> _all;

  static const _featuredIso = ['CM', 'CI', 'CD', 'CG', 'SN'];

  @override
  void initState() {
    super.initState();
    final featured = _featuredIso
        .map((i) => _kCountries.firstWhere((c) => c.iso == i))
        .toList();
    final rest = [..._kCountries]
      ..removeWhere((c) => _featuredIso.contains(c.iso))
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _all = [...featured, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _all
        : _all
            .where((c) =>
                c.name.toLowerCase().contains(_query.toLowerCase()) ||
                c.dial.contains(_query))
            .toList();

    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.78,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E6EE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Indicatif / code du pays',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Rechercher',
                  hintStyle: const TextStyle(color: _kHint),
                  prefixIcon: const Icon(Icons.search, color: _kHint),
                  filled: true,
                  fillColor: _kFieldFill,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Color(0xFFF0F1F4),
                ),
                itemBuilder: (_, i) {
                  final c = filtered[i];
                  return ListTile(
                    leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title: Text(
                      c.name,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    trailing: Text(
                      c.dial,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════
//  MODÈLE PAYS + DONNÉES
// ═════════════════════════════════════════════════════════════════════════

class _Country {
  final String iso;
  final String name;
  final String? nameEn;
  final String dial;
  final String flag;
  const _Country(this.iso, this.name, this.dial, this.flag, {this.nameEn});
}

/// Liste (non exhaustive, suffisante pour le picker).
const List<_Country> _kCountries = [
  _Country('AF', 'Afghanistan', '+93', '🇦🇫'),
  _Country('AX', 'Åland', '+358', '🇦🇽'),
  _Country('AL', 'Albanie', '+355', '🇦🇱'),
  _Country('DZ', 'Algérie', '+213', '🇩🇿'),
  _Country('DE', 'Allemagne', '+49', '🇩🇪'),
  _Country('AD', 'Andorre', '+376', '🇦🇩'),
  _Country('AO', 'Angola', '+244', '🇦🇴'),
  _Country('AI', 'Anguilla', '+1264', '🇦🇮'),
  _Country('AQ', 'Antarctique', '+672', '🇦🇶'),
  _Country('AG', 'Antigua-et-Barbuda', '+1268', '🇦🇬'),
  _Country('SA', 'Arabie saoudite', '+966', '🇸🇦'),
  _Country('AR', 'Argentine', '+54', '🇦🇷'),
  _Country('AM', 'Arménie', '+374', '🇦🇲'),
  _Country('AW', 'Aruba', '+297', '🇦🇼'),
  _Country('AU', 'Australie', '+61', '🇦🇺'),
  _Country('AT', 'Autriche', '+43', '🇦🇹'),
  _Country('AZ', 'Azerbaïdjan', '+994', '🇦🇿'),
  _Country('BS', 'Bahamas', '+1242', '🇧🇸'),
  _Country('BH', 'Bahreïn', '+973', '🇧🇭'),
  _Country('BD', 'Bangladesh', '+880', '🇧🇩'),
  _Country('BB', 'Barbade', '+1246', '🇧🇧'),
  _Country('BE', 'Belgique', '+32', '🇧🇪'),
  _Country('BZ', 'Belize', '+501', '🇧🇿'),
  _Country('BJ', 'Bénin', '+229', '🇧🇯'),
  _Country('BM', 'Bermudes', '+1441', '🇧🇲'),
  _Country('BT', 'Bhoutan', '+975', '🇧🇹'),
  _Country('BY', 'Biélorussie', '+375', '🇧🇾'),
  _Country('BO', 'Bolivie', '+591', '🇧🇴'),
  _Country('BA', 'Bosnie-Herzégovine', '+387', '🇧🇦'),
  _Country('BW', 'Botswana', '+267', '🇧🇼'),
  _Country('BR', 'Brésil', '+55', '🇧🇷'),
  _Country('BN', 'Brunei', '+673', '🇧🇳'),
  _Country('BG', 'Bulgarie', '+359', '🇧🇬'),
  _Country('BF', 'Burkina Faso', '+226', '🇧🇫'),
  _Country('BI', 'Burundi', '+257', '🇧🇮'),
  _Country('KH', 'Cambodge', '+855', '🇰🇭'),
  _Country('CM', 'Cameroun', '+237', '🇨🇲', nameEn: 'Cameroon'),
  _Country('CA', 'Canada', '+1', '🇨🇦'),
  _Country('CV', 'Cap-Vert', '+238', '🇨🇻'),
  _Country('CL', 'Chili', '+56', '🇨🇱'),
  _Country('CN', 'Chine', '+86', '🇨🇳'),
  _Country('CY', 'Chypre', '+357', '🇨🇾'),
  _Country('CO', 'Colombie', '+57', '🇨🇴'),
  _Country('KM', 'Comores', '+269', '🇰🇲'),
  _Country('CG', 'Congo', '+242', '🇨🇬'),
  _Country('CD', 'Congo (RDC)', '+243', '🇨🇩'),
  _Country('KP', 'Corée du Nord', '+850', '🇰🇵'),
  _Country('KR', 'Corée du Sud', '+82', '🇰🇷'),
  _Country('CR', 'Costa Rica', '+506', '🇨🇷'),
  _Country('CI', 'Cote D\'Ivoire', '+225', '🇨🇮', nameEn: 'Ivory Coast'),
  _Country('HR', 'Croatie', '+385', '🇭🇷'),
  _Country('CU', 'Cuba', '+53', '🇨🇺'),
  _Country('DK', 'Danemark', '+45', '🇩🇰'),
  _Country('DJ', 'Djibouti', '+253', '🇩🇯'),
  _Country('DM', 'Dominique', '+1767', '🇩🇲'),
  _Country('EG', 'Égypte', '+20', '🇪🇬'),
  _Country('AE', 'Émirats arabes unis', '+971', '🇦🇪'),
  _Country('EC', 'Équateur', '+593', '🇪🇨'),
  _Country('ER', 'Érythrée', '+291', '🇪🇷'),
  _Country('ES', 'Espagne', '+34', '🇪🇸'),
  _Country('EE', 'Estonie', '+372', '🇪🇪'),
  _Country('US', 'États-Unis', '+1', '🇺🇸'),
  _Country('ET', 'Éthiopie', '+251', '🇪🇹'),
  _Country('FJ', 'Fidji', '+679', '🇫🇯'),
  _Country('FI', 'Finlande', '+358', '🇫🇮'),
  _Country('FR', 'France', '+33', '🇫🇷'),
  _Country('GA', 'Gabon', '+241', '🇬🇦'),
  _Country('GM', 'Gambie', '+220', '🇬🇲'),
  _Country('GE', 'Géorgie', '+995', '🇬🇪'),
  _Country('GH', 'Ghana', '+233', '🇬🇭'),
  _Country('GR', 'Grèce', '+30', '🇬🇷'),
  _Country('GD', 'Grenade', '+1473', '🇬🇩'),
  _Country('GL', 'Groenland', '+299', '🇬🇱'),
  _Country('GP', 'Guadeloupe', '+590', '🇬🇵'),
  _Country('GU', 'Guam', '+1671', '🇬🇺'),
  _Country('GT', 'Guatemala', '+502', '🇬🇹'),
  _Country('GG', 'Guernesey', '+44', '🇬🇬'),
  _Country('GN', 'Guinée', '+224', '🇬🇳'),
  _Country('GQ', 'Guinée équatoriale', '+240', '🇬🇶'),
  _Country('GW', 'Guinée-Bissau', '+245', '🇬🇼'),
  _Country('GY', 'Guyana', '+592', '🇬🇾'),
  _Country('GF', 'Guyane française', '+594', '🇬🇫'),
  _Country('HT', 'Haïti', '+509', '🇭🇹'),
  _Country('HN', 'Honduras', '+504', '🇭🇳'),
  _Country('HK', 'Hong Kong', '+852', '🇭🇰'),
  _Country('HU', 'Hongrie', '+36', '🇭🇺'),
  _Country('IN', 'Inde', '+91', '🇮🇳'),
  _Country('ID', 'Indonésie', '+62', '🇮🇩'),
  _Country('IQ', 'Irak', '+964', '🇮🇶'),
  _Country('IR', 'Iran', '+98', '🇮🇷'),
  _Country('IE', 'Irlande', '+353', '🇮🇪'),
  _Country('IS', 'Islande', '+354', '🇮🇸'),
  _Country('IL', 'Israël', '+972', '🇮🇱'),
  _Country('IT', 'Italie', '+39', '🇮🇹'),
  _Country('JM', 'Jamaïque', '+1876', '🇯🇲'),
  _Country('JP', 'Japon', '+81', '🇯🇵'),
  _Country('JO', 'Jordanie', '+962', '🇯🇴'),
  _Country('KZ', 'Kazakhstan', '+7', '🇰🇿'),
  _Country('KE', 'Kenya', '+254', '🇰🇪'),
  _Country('KG', 'Kirghizistan', '+996', '🇰🇬'),
  _Country('KI', 'Kiribati', '+686', '🇰🇮'),
  _Country('KW', 'Koweït', '+965', '🇰🇼'),
  _Country('LA', 'Laos', '+856', '🇱🇦'),
  _Country('LS', 'Lesotho', '+266', '🇱🇸'),
  _Country('LV', 'Lettonie', '+371', '🇱🇻'),
  _Country('LB', 'Liban', '+961', '🇱🇧'),
  _Country('LR', 'Libéria', '+231', '🇱🇷'),
  _Country('LY', 'Libye', '+218', '🇱🇾'),
  _Country('LI', 'Liechtenstein', '+423', '🇱🇮'),
  _Country('LT', 'Lituanie', '+370', '🇱🇹'),
  _Country('LU', 'Luxembourg', '+352', '🇱🇺'),
  _Country('MO', 'Macao', '+853', '🇲🇴'),
  _Country('MK', 'Macédoine du Nord', '+389', '🇲🇰'),
  _Country('MG', 'Madagascar', '+261', '🇲🇬'),
  _Country('MY', 'Malaisie', '+60', '🇲🇾'),
  _Country('MW', 'Malawi', '+265', '🇲🇼'),
  _Country('MV', 'Maldives', '+960', '🇲🇻'),
  _Country('ML', 'Mali', '+223', '🇲🇱'),
  _Country('MT', 'Malte', '+356', '🇲🇹'),
  _Country('MA', 'Maroc', '+212', '🇲🇦'),
  _Country('MQ', 'Martinique', '+596', '🇲🇶'),
  _Country('MU', 'Maurice', '+230', '🇲🇺'),
  _Country('MR', 'Mauritanie', '+222', '🇲🇷'),
  _Country('MX', 'Mexique', '+52', '🇲🇽'),
  _Country('MD', 'Moldavie', '+373', '🇲🇩'),
  _Country('MC', 'Monaco', '+377', '🇲🇨'),
  _Country('MN', 'Mongolie', '+976', '🇲🇳'),
  _Country('ME', 'Monténégro', '+382', '🇲🇪'),
  _Country('MS', 'Montserrat', '+1664', '🇲🇸'),
  _Country('MZ', 'Mozambique', '+258', '🇲🇿'),
  _Country('MM', 'Myanmar', '+95', '🇲🇲'),
  _Country('NA', 'Namibie', '+264', '🇳🇦'),
  _Country('NR', 'Nauru', '+674', '🇳🇷'),
  _Country('NP', 'Népal', '+977', '🇳🇵'),
  _Country('NI', 'Nicaragua', '+505', '🇳🇮'),
  _Country('NE', 'Niger', '+227', '🇳🇪'),
  _Country('NG', 'Nigéria', '+234', '🇳🇬'),
  _Country('NO', 'Norvège', '+47', '🇳🇴'),
  _Country('NC', 'Nouvelle-Calédonie', '+687', '🇳🇨'),
  _Country('NZ', 'Nouvelle-Zélande', '+64', '🇳🇿'),
  _Country('OM', 'Oman', '+968', '🇴🇲'),
  _Country('UG', 'Ouganda', '+256', '🇺🇬'),
  _Country('UZ', 'Ouzbékistan', '+998', '🇺🇿'),
  _Country('PK', 'Pakistan', '+92', '🇵🇰'),
  _Country('PW', 'Palaos', '+680', '🇵🇼'),
  _Country('PA', 'Panama', '+507', '🇵🇦'),
  _Country('PG', 'Papouasie-Nouvelle-Guinée', '+675', '🇵🇬'),
  _Country('PY', 'Paraguay', '+595', '🇵🇾'),
  _Country('NL', 'Pays-Bas', '+31', '🇳🇱'),
  _Country('PE', 'Pérou', '+51', '🇵🇪'),
  _Country('PH', 'Philippines', '+63', '🇵🇭'),
  _Country('PL', 'Pologne', '+48', '🇵🇱'),
  _Country('PF', 'Polynésie française', '+689', '🇵🇫'),
  _Country('PR', 'Porto Rico', '+1787', '🇵🇷'),
  _Country('PT', 'Portugal', '+351', '🇵🇹'),
  _Country('QA', 'Qatar', '+974', '🇶🇦'),
  _Country('RE', 'La Réunion', '+262', '🇷🇪'),
  _Country('RO', 'Roumanie', '+40', '🇷🇴'),
  _Country('GB', 'Royaume-Uni', '+44', '🇬🇧'),
  _Country('RU', 'Russie', '+7', '🇷🇺'),
  _Country('RW', 'Rwanda', '+250', '🇷🇼'),
  _Country('SV', 'Salvador', '+503', '🇸🇻'),
  _Country('WS', 'Samoa', '+685', '🇼🇸'),
  _Country('SM', 'Saint-Marin', '+378', '🇸🇲'),
  _Country('SN', 'Sénégal', '+221', '🇸🇳'),
  _Country('RS', 'Serbie', '+381', '🇷🇸'),
  _Country('SC', 'Seychelles', '+248', '🇸🇨'),
  _Country('SL', 'Sierra Leone', '+232', '🇸🇱'),
  _Country('SG', 'Singapour', '+65', '🇸🇬'),
  _Country('SK', 'Slovaquie', '+421', '🇸🇰'),
  _Country('SI', 'Slovénie', '+386', '🇸🇮'),
  _Country('SO', 'Somalie', '+252', '🇸🇴'),
  _Country('SD', 'Soudan', '+249', '🇸🇩'),
  _Country('SS', 'Soudan du Sud', '+211', '🇸🇸'),
  _Country('LK', 'Sri Lanka', '+94', '🇱🇰'),
  _Country('SE', 'Suède', '+46', '🇸🇪'),
  _Country('CH', 'Suisse', '+41', '🇨🇭'),
  _Country('SR', 'Suriname', '+597', '🇸🇷'),
  _Country('SY', 'Syrie', '+963', '🇸🇾'),
  _Country('TJ', 'Tadjikistan', '+992', '🇹🇯'),
  _Country('TW', 'Taïwan', '+886', '🇹🇼'),
  _Country('TZ', 'Tanzanie', '+255', '🇹🇿'),
  _Country('TD', 'Tchad', '+235', '🇹🇩'),
  _Country('CZ', 'Tchéquie', '+420', '🇨🇿'),
  _Country('TH', 'Thaïlande', '+66', '🇹🇭'),
  _Country('TL', 'Timor oriental', '+670', '🇹🇱'),
  _Country('TG', 'Togo', '+228', '🇹🇬'),
  _Country('TO', 'Tonga', '+676', '🇹🇴'),
  _Country('TT', 'Trinité-et-Tobago', '+1868', '🇹🇹'),
  _Country('TN', 'Tunisie', '+216', '🇹🇳'),
  _Country('TM', 'Turkménistan', '+993', '🇹🇲'),
  _Country('TR', 'Turquie', '+90', '🇹🇷'),
  _Country('UA', 'Ukraine', '+380', '🇺🇦'),
  _Country('UY', 'Uruguay', '+598', '🇺🇾'),
  _Country('VU', 'Vanuatu', '+678', '🇻🇺'),
  _Country('VA', 'Vatican', '+379', '🇻🇦'),
  _Country('VE', 'Venezuela', '+58', '🇻🇪'),
  _Country('VN', 'Vietnam', '+84', '🇻🇳'),
  _Country('YE', 'Yémen', '+967', '🇾🇪'),
  _Country('ZM', 'Zambie', '+260', '🇿🇲'),
  _Country('ZW', 'Zimbabwe', '+263', '🇿🇼'),
];

// ═════════════════════════════════════════════════════════════════════════
//  DOCUMENTS — modèle local
// ═════════════════════════════════════════════════════════════════════════

class _PendingDocument {
  final int typeDocumentId;
  final String typeNom;
  final String? reference;
  final DateTime? dateEmission;
  final DateTime? dateExpiration;
  final Uint8List bytes;
  final String filename;
  final List<String> typesPermis;
  final bool permanent;

  const _PendingDocument({
    required this.typeDocumentId,
    required this.typeNom,
    this.reference,
    this.dateEmission,
    this.dateExpiration,
    required this.bytes,
    required this.filename,
    this.typesPermis = const [],
    this.permanent = false,
  });
}

// ── État vide documents ───────────────────────────────────────────────────

class _EmptyDocState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EE)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF2F3F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.description_outlined,
                size: 32, color: _kHint),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aucune pièce ajoutée',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(height: 6),
          Text(
            "Permis, carte d'identité, contrat…",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

// ── Carte pièce en attente ────────────────────────────────────────────────

class _PendingDocCard extends StatelessWidget {
  final _PendingDocument doc;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  const _PendingDocCard(
      {required this.doc, required this.onRemove, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E6EE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: _kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.typeNom,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E)),
                  ),
                  if (doc.reference != null &&
                      doc.reference!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Réf : ${doc.reference}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                  if (doc.dateExpiration != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Exp : ${doc.dateExpiration!.day.toString().padLeft(2, '0')}/${doc.dateExpiration!.month.toString().padLeft(2, '0')}/${doc.dateExpiration!.year}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.attach_file,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          doc.filename,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
              color: Colors.grey.shade400,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte pièce existante ─────────────────────────────────────────────────

class _ExistingDocCard extends StatelessWidget {
  final DocumentChauffeurLocal doc;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const _ExistingDocCard(
      {required this.doc, this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E6EE)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_outlined,
                  color: _kHint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.displayName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A2E)),
                  ),
                  if (doc.dateEmission != null ||
                      doc.dateExpiration != null) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (doc.dateEmission != null)
                          Text(
                            'Ém : ${doc.dateEmission!.day.toString().padLeft(2, '0')}/${doc.dateEmission!.month.toString().padLeft(2, '0')}/${doc.dateEmission!.year}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        if (doc.dateExpiration != null)
                          Text(
                            'Exp : ${doc.dateExpiration!.day.toString().padLeft(2, '0')}/${doc.dateExpiration!.month.toString().padLeft(2, '0')}/${doc.dateExpiration!.year}',
                            style: TextStyle(
                              fontSize: 12,
                              color: (doc.statut == 'EXPIRE')
                                  ? const Color(0xFFE03131)
                                  : Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (doc.fichierNom != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.attach_file,
                            size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doc.fichierNom!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red.shade300,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheet : ajout d'une pièce ─────────────────────────────────────

class _AddDocumentSheet extends StatefulWidget {
  final List<TypeDocument> types;
  final _PendingDocument? initialDoc;
  final DocumentChauffeurLocal? existingDoc;
  final Uint8List? existingBytes;

  const _AddDocumentSheet(
      {required this.types,
      this.initialDoc,
      this.existingDoc,
      this.existingBytes});

  @override
  State<_AddDocumentSheet> createState() => _AddDocumentSheetState();
}

class _AddDocumentSheetState extends State<_AddDocumentSheet> {
  TypeDocument? _selectedType;
  final _referenceCtrl = TextEditingController();
  DateTime? _dateEmission;
  DateTime? _dateExpiration;
  Uint8List? _fileBytes;
  String? _fileName;
  List<String> _typesPermis = [];
  bool _permanent = false;

  // ── Inline toast (banner affiché dans la sheet) ──
  String? _inlineMsg;
  _ToastType _inlineType = _ToastType.error;
  Timer? _inlineTimer;

  void _showInline(String msg, {_ToastType type = _ToastType.error}) {
    _inlineTimer?.cancel();
    setState(() { _inlineMsg = msg; _inlineType = type; });
    _inlineTimer = Timer(
      Duration(seconds: type == _ToastType.error || type == _ToastType.warning ? 4 : 2),
      () { if (mounted) setState(() => _inlineMsg = null); },
    );
  }

  bool get _isPermis =>
      (_selectedType?.nom ?? '').toLowerCase().contains('permis');

  @override
  void initState() {
    super.initState();
    final init = widget.initialDoc;
    if (init != null) {
      for (final t in widget.types) {
        if (t.id == init.typeDocumentId) {
          _selectedType = t;
          break;
        }
      }
      _referenceCtrl.text = init.reference ?? '';
      _dateEmission = init.dateEmission;
      _dateExpiration = init.dateExpiration;
      _fileBytes = init.bytes;
      _fileName = init.filename;
      _typesPermis = init.typesPermis.toList();
      _permanent = init.permanent;
    }
    final existing = widget.existingDoc;
    if (existing != null) {
      for (final t in widget.types) {
        if (t.nom == existing.typeNom) {
          _selectedType = t;
          break;
        }
      }
      _referenceCtrl.text = existing.reference ?? '';
      _dateEmission = existing.dateEmission;
      _dateExpiration = existing.dateExpiration;
      _typesPermis = existing.categorie.toList();
      _permanent = existing.permanent;
      if (widget.existingBytes != null && existing.fichierNom != null) {
        _fileBytes = widget.existingBytes;
        _fileName = existing.fichierNom;
      }
    }
  }

  @override
  void dispose() {
    _inlineTimer?.cancel();
    _referenceCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate(
      DateTime? initial, ValueChanged<DateTime> onPicked) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 20),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _pickFile() async {
    final action = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E6EE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined,
                  color: Colors.black87),
              title: const Text('Appareil photo',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined,
                  color: Colors.black87),
              title: const Text('Fichier (PDF, image)',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, 1),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    Uint8List? bytes;
    String? name;

    if (action == 0) {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 85);
      if (img != null) {
        bytes = await img.readAsBytes();
        name = img.name;
      }
    } else if (action == 1) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'heic'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        bytes = file.bytes;
        name = file.name;
      }
    }

    if (bytes != null && name != null && mounted) {
      setState(() {
        _fileBytes = bytes;
        _fileName = name;
      });
    }
  }

  void _previewFile() {
    if (_fileBytes == null) return;
    showDialog(
      context: context,
      builder: (_) =>
          _FilePreviewDialog(bytes: _fileBytes!, filename: _fileName!),
    );
  }

  void _confirm() {
    if (_selectedType == null) {
      _showInline('Sélectionnez un type de document.');
      return;
    }
    if (_isPermis && _typesPermis.isEmpty) {
      _showInline('Veuillez sélectionner au moins une catégorie.');
      return;
    }
    if (_referenceCtrl.text.trim().isEmpty) {
      _showInline('Veuillez renseigner la référence du document.');
      return;
    }
    if (_fileBytes == null) {
      _showInline('Veuillez joindre un fichier.');
      return;
    }
    Navigator.pop(
      context,
      _PendingDocument(
        typeDocumentId: _selectedType!.id,
        typeNom: _selectedType!.nom,
        reference: _referenceCtrl.text.trim(),
        dateEmission: _dateEmission,
        dateExpiration: _permanent ? null : _dateExpiration,
        bytes: _fileBytes!,
        filename: _fileName!,
        typesPermis: _isPermis ? List.unmodifiable(_typesPermis) : const [],
        permanent: _permanent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (_, ctrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE1EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                // ── Banner d'erreur/succès inline ──────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _InlineToastBanner(
                    key: ValueKey(_inlineMsg),
                    message: _inlineMsg,
                    type: _inlineType,
                  ),
                ),
                // Type de document
                _DocLabeledField(
                  label: 'Type de document',
                  isRequired: true,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kFieldFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<TypeDocument?>(
                        value: _selectedType,
                        isExpanded: true,
                        hint: const Text('Sélectionner',
                            style:
                                TextStyle(color: _kHint, fontSize: 15)),
                        borderRadius: BorderRadius.circular(14),
                        menuMaxHeight: 320,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: _kHint, size: 18),
                        onChanged: (t) =>
                            setState(() => _selectedType = t),
                        items: widget.types
                            .map((t) => DropdownMenuItem<TypeDocument?>(
                                  value: t,
                                  child: Text(t.nom,
                                      style: const TextStyle(
                                          fontSize: 15)),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                // Champs spécifiques au permis de conduire
                if (_isPermis) ...[
                  const SizedBox(height: 12),
                  _DocLabeledField(
                    label: 'Catégorie',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['A', 'B', 'C', 'D', 'E'].map((cat) {
                        final sel = _typesPermis.contains(cat);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (sel) {
                              _typesPermis.remove(cat);
                            } else {
                              _typesPermis.add(cat);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: sel ? _kPrimary : _kFieldFill,
                              borderRadius: BorderRadius.circular(10),
                              border: sel
                                  ? null
                                  : Border.all(
                                      color: const Color(0xFFE3E6EE)),
                            ),
                            child: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: sel
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color:
                                    sel ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Référence
                _DocLabeledField(
                  label: 'Référence',
                  isRequired: true,
                  child: _DocPlainField(
                    controller: _referenceCtrl,
                    hint: 'Ex : CI-2024-001',
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Permanent',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kLabel,
                      ),
                    ),
                    Switch(
                      value: _permanent,
                      activeThumbColor: _kPrimary,
                      onChanged: (v) => setState(() {
                        _permanent = v;
                        if (v) _dateExpiration = null;
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Dates
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _DocLabeledField(
                        label: "Date d'émission",
                        child: _DocDateField(
                          label: 'JJ/MM/AAAA',
                          value: _dateEmission,
                          formatter: _fmt,
                          onTap: () => _pickDate(
                            _dateEmission,
                            (d) => setState(() => _dateEmission = d),
                          ),
                        ),
                      ),
                    ),
                    if (!_permanent) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DocLabeledField(
                          label: "Date d'expiration",
                          child: _DocDateField(
                            label: 'JJ/MM/AAAA',
                            value: _dateExpiration,
                            formatter: _fmt,
                            onTap: () => _pickDate(
                              _dateExpiration,
                              (d) => setState(() => _dateExpiration = d),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // Fichier
                _DocLabeledField(
                  label: 'Fichier',
                  isRequired: true,
                  child: GestureDetector(
                    onTap:
                        _fileBytes == null ? _pickFile : _previewFile,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: _fileBytes != null
                            ? const Color(0xFFEEF2FF)
                            : _kFieldFill,
                        borderRadius: BorderRadius.circular(12),
                        border: _fileBytes != null
                            ? Border.all(
                                color: _kPrimary.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _fileBytes != null
                                ? Icons.check_circle_outline
                                : Icons.attach_file,
                            size: 18,
                            color: _fileBytes != null ? _kPrimary : _kHint,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _fileName ?? 'Choisir un fichier',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                color: _fileBytes != null
                                    ? _kPrimary
                                    : _kHint,
                              ),
                            ),
                          ),
                          if (_fileBytes != null)
                            GestureDetector(
                              onTap: _pickFile,
                              child: Icon(Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.grey.shade400),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      (widget.initialDoc != null ||
                              widget.existingDoc != null)
                          ? 'Modifier'
                          : 'Ajouter',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog aperçu fichier ─────────────────────────────────────────────────

class _FilePreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final String filename;

  const _FilePreviewDialog(
      {required this.bytes, required this.filename});

  @override
  State<_FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<_FilePreviewDialog> {
  PdfController? _pdfController;
  bool _pdfLoading = false;
  bool _pdfError = false;

  static bool _isBytesPdf(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x25 &&
      b[1] == 0x50 &&
      b[2] == 0x44 &&
      b[3] == 0x46;

  bool get _isPdf =>
      _isBytesPdf(widget.bytes) ||
      widget.filename.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    if (_isPdf) {
      _pdfLoading = true;
      _initPdf();
    }
  }

  Future<void> _initPdf() async {
    try {
      final doc = await PdfDocument.openData(widget.bytes);
      if (!mounted) return;
      setState(() {
        _pdfController = PdfController(document: Future.value(doc));
        _pdfLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pdfError = true;
        _pdfLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.filename,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(minHeight: 180, maxHeight: 420),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _isPdf
                        ? _pdfLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.white54, strokeWidth: 2),
                              )
                            : (_pdfError || _pdfController == null)
                                ? const Center(
                                    child: Text('Impossible de lire le PDF.',
                                        style: TextStyle(
                                            color: Colors.white38)),
                                  )
                                : PdfView(
                                    controller: _pdfController!,
                                    scrollDirection: Axis.vertical,
                                    pageSnapping: false,
                                    backgroundDecoration: const BoxDecoration(
                                        color: Color(0xFF12122A)),
                                  )
                        : InteractiveViewer(
                            minScale: 0.5,
                            maxScale: 5.0,
                            child: Image.memory(
                              widget.bytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers de formulaire pour le bottom sheet ────────────────────────────

class _DocLabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isRequired;

  const _DocLabeledField(
      {required this.label, required this.child, this.isRequired = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        isRequired
            ? RichText(
                text: TextSpan(
                  text: label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kLabel,
                  ),
                  children: const [
                    TextSpan(
                      text: ' *',
                      style: TextStyle(
                          color: Colors.red, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kLabel,
                ),
              ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DocPlainField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _DocPlainField(
      {required this.controller,
      required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kHint, fontSize: 15),
        filled: true,
        fillColor: _kFieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              const BorderSide(color: _kPrimary, width: 1.2),
        ),
      ),
    );
  }
}

class _DocDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String Function(DateTime) formatter;
  final VoidCallback onTap;

  const _DocDateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value != null ? formatter(value!) : label,
                style: TextStyle(
                  fontSize: 15,
                  color: value != null ? Colors.black87 : _kHint,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: _kHint),
          ],
        ),
      ),
    );
  }
}


