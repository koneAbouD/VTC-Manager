import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/utils/image_source_bottom_sheet.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/network_photo_viewer.dart';
import '../../../../core/widgets/responsive_field_row.dart';
import '../../data/datasources/referentiel_datasource.dart';
import '../../domain/entities/vehicule.dart';
import '../providers/documents_by_vehicule_provider.dart';
import '../providers/referentiel_provider.dart';
import '../providers/type_document_provider.dart';
import '../providers/vehicule_provider.dart'
    show vehiculeNotifierProvider, vehiculeDatasourceProvider;
import '../../../configuration_vehicule/presentation/pages/configuration_vehicule_page.dart';
import '../../../groupe/presentation/pages/groupe_selector_page.dart';
import '../vehicule_couleurs.dart';
import '../../../../core/theme/app_colors.dart';

const _kPrimary = AppColors.primary;
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint = Color(0xFF9AA0AE);
const _kLabel = Color(0xFF6B7280);
const _kBorder = Color(0xFFE3E6EE);

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

// ── Banner inline (bottom sheets document) ────────────────────────────────────

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

// ── Modèles locaux ────────────────────────────────────────────────────────────

class _PendingDocument {
  final int typeDocumentId;
  final String typeNom;
  final String? reference;
  final DateTime? dateEmission;
  final DateTime? dateExpiration;
  final Uint8List bytes;
  final String filename;
  final bool permanent;

  const _PendingDocument({
    required this.typeDocumentId,
    required this.typeNom,
    this.reference,
    this.dateEmission,
    this.dateExpiration,
    required this.bytes,
    required this.filename,
    this.permanent = false,
  });
}

// ── Providers locaux ──────────────────────────────────────────────────────────

final _vehiculeFormSecureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(),
);

final _vehiculeFormApiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(_vehiculeFormSecureStorageProvider)),
);

// ── Page ──────────────────────────────────────────────────────────────────────

class VehiculeFormPage extends ConsumerStatefulWidget {
  final Vehicule? initial;
  const VehiculeFormPage({super.key, this.initial});

  @override
  ConsumerState<VehiculeFormPage> createState() => _VehiculeFormPageState();
}

class _VehiculeFormPageState extends ConsumerState<VehiculeFormPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  final _formKey = GlobalKey<FormState>();
  final _immatCtrl = TextEditingController();
  final _chassisCtrl = TextEditingController();
  final _telVehiculeCtrl = TextEditingController();
  final _telBaliseCtrl = TextEditingController();
  final _idBaliseCtrl = TextEditingController();

  ReferentielItem? _typeVehicule;
  ReferentielItem? _typeActivite;
  ReferentielItem? _marque;
  ReferentielItem? _modele;
  ReferentielItem? _groupe;
  String? _couleur;
  DateTime? _dateMiseEnCirculation;
  DateTime? _dateEntreeFlotte;
  bool _loading = false;
  String? _submitError;
  final List<XFile> _photos = [];
  List<VehiculePhoto> _existingPhotos = [];
  static const _maxPhotos = 4;
  String? _immatError;

  // Sections de l'accordéon ouvertes (indices 0-4)
  final Set<int> _expandedSections = {0};

  final List<_PendingDocument> _pendingDocuments = [];

  // Snapshot initial pour détecter les modifications
  late final String _initImmat;
  late final String _initChassis;
  late final String _initTelVehicule;
  late final String _initTelBalise;
  late final String _initIdBalise;
  late final ReferentielItem? _initTypeVehicule;
  late final ReferentielItem? _initTypeActivite;
  late final ReferentielItem? _initMarque;
  late final ReferentielItem? _initModele;
  late final ReferentielItem? _initGroupe;
  late final String? _initCouleur;
  late final DateTime? _initDateMEC;
  late final DateTime? _initDateFlotte;
  late final int _initExistingPhotosCount;

  bool get _isEditing => widget.initial != null;

  bool get _hasChanges =>
      _immatCtrl.text != _initImmat ||
      _chassisCtrl.text != _initChassis ||
      _telVehiculeCtrl.text != _initTelVehicule ||
      _telBaliseCtrl.text != _initTelBalise ||
      _idBaliseCtrl.text != _initIdBalise ||
      _typeVehicule?.id != _initTypeVehicule?.id ||
      _typeActivite?.id != _initTypeActivite?.id ||
      _marque?.id != _initMarque?.id ||
      _modele?.id != _initModele?.id ||
      _groupe?.id != _initGroupe?.id ||
      _couleur != _initCouleur ||
      _dateMiseEnCirculation != _initDateMEC ||
      _dateEntreeFlotte != _initDateFlotte ||
      _photos.isNotEmpty ||
      _existingPhotos.length != _initExistingPhotosCount;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);

    final v = widget.initial;
    if (v != null) {
      _immatCtrl.text = v.immatriculation;
      _chassisCtrl.text = v.numeroChassis ?? '';
      _telVehiculeCtrl.text = v.numeroTelephoneVehicule ?? '';
      _telBaliseCtrl.text = v.numeroTelephoneBalise ?? '';
      _idBaliseCtrl.text = v.identifiantBalise ?? '';
      _couleur = v.couleur;
      _dateMiseEnCirculation = v.dateMiseEnCirculation;
      _dateEntreeFlotte = v.dateEntreeFlotte;
      if (v.typeVehiculeId != null) {
        _typeVehicule = ReferentielItem(
            id: v.typeVehiculeId!, nom: v.typeVehiculeNom ?? '—');
      }
      if (v.typeActiviteId != null) {
        _typeActivite = ReferentielItem(
            id: v.typeActiviteId!, nom: v.typeActiviteNom ?? '—');
      }
      if (v.marqueId != null) {
        _marque = ReferentielItem(id: v.marqueId!, nom: v.marque);
      }
      if (v.modeleId != null) {
        _modele = ReferentielItem(id: v.modeleId!, nom: v.modele);
      }
      if (v.groupeId != null) {
        _groupe = ReferentielItem(id: v.groupeId!, nom: v.groupe ?? '—');
      }
      if (v.photos != null) _existingPhotos = List.from(v.photos!);
    }

    // Snapshot après hydratation des champs
    _initImmat = _immatCtrl.text;
    _initChassis = _chassisCtrl.text;
    _initTelVehicule = _telVehiculeCtrl.text;
    _initTelBalise = _telBaliseCtrl.text;
    _initIdBalise = _idBaliseCtrl.text;
    _initTypeVehicule = _typeVehicule;
    _initTypeActivite = _typeActivite;
    _initMarque = _marque;
    _initModele = _modele;
    _initGroupe = _groupe;
    _initCouleur = _couleur;
    _initDateMEC = _dateMiseEnCirculation;
    _initDateFlotte = _dateEntreeFlotte;
    _initExistingPhotosCount = _existingPhotos.length;

    _immatCtrl.addListener(_onTextChanged);
    _chassisCtrl.addListener(_onTextChanged);
    _telVehiculeCtrl.addListener(_onTextChanged);
    _telBaliseCtrl.addListener(_onTextChanged);
    _idBaliseCtrl.addListener(_onTextChanged);

    // En mode édition : section 0 reste ouverte, les autres fermées
    if (_isEditing) {
      _expandedSections.clear();
      _expandedSections.add(0);
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _immatCtrl.removeListener(_onTextChanged);
    _chassisCtrl.removeListener(_onTextChanged);
    _telVehiculeCtrl.removeListener(_onTextChanged);
    _telBaliseCtrl.removeListener(_onTextChanged);
    _idBaliseCtrl.removeListener(_onTextChanged);
    _tabCtrl.dispose();
    _immatCtrl.dispose();
    _chassisCtrl.dispose();
    _telVehiculeCtrl.dispose();
    _telBaliseCtrl.dispose();
    _idBaliseCtrl.dispose();
    super.dispose();
  }

  // ── Accordéon ─────────────────────────────────────────────────────────────

  void _toggleSection(int i) {
    setState(() {
      if (_expandedSections.contains(i)) {
        _expandedSections.remove(i);
      } else {
        _expandedSections.add(i);
      }
    });
  }

  // Résumés affichés dans les headers fermés
  String? get _vehiculeSummary {
    final parts = <String>[
      if (_marque != null && _modele != null) '${_marque!.nom} ${_modele!.nom}',
      if (_immatCtrl.text.trim().isNotEmpty) _immatCtrl.text.trim(),
      if (_couleur != null) _couleur!,
    ];
    if (parts.isEmpty) {
      final base = [_typeActivite?.nom, _typeVehicule?.nom]
          .where((s) => s != null).join(' · ');
      return base.isEmpty ? null : base;
    }
    return parts.join(' · ');
  }

  String? get _infosSuppSummary {
    final datePart = _datesSummary;
    final optCount = [
      _telBaliseCtrl.text.trim(),
      _idBaliseCtrl.text.trim(),
    ].where((s) => s.isNotEmpty).length + (_groupe != null ? 1 : 0);
    if (datePart == null && optCount == 0) return null;
    final parts = <String>[
      if (datePart != null) datePart,
      if (optCount > 0)
        '+ $optCount option${optCount > 1 ? "s" : ""}',
    ];
    return parts.join(' · ');
  }

  String? get _datesSummary {
    if (_dateMiseEnCirculation == null && _dateEntreeFlotte == null) return null;
    return [
      if (_dateMiseEnCirculation != null) _formatDate(_dateMiseEnCirculation!),
      if (_dateEntreeFlotte != null) _formatDate(_dateEntreeFlotte!),
    ].join(' → ');
  }

  // ── Date picker ────────────────────────────────────────────────────────────

  Future<void> _pickDate({
    required DateTime? initial,
    required ValueChanged<DateTime> onPicked,
    DateTime? minDate,
    DateTime? maxDate,
  }) async {
    final now = DateTime.now();
    final firstDate = minDate ?? DateTime(1980);
    final lastDate = maxDate ?? DateTime(now.year + 1, now.month, now.day);
    DateTime base = initial ?? now;
    if (base.isBefore(firstDate)) base = firstDate;
    if (base.isAfter(lastDate)) base = lastDate;

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: base,
        firstDate: firstDate,
        lastDate: lastDate,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Validation & navigation ───────────────────────────────────────────────

  bool _validateInformations() {
    final formState = _formKey.currentState;
    if (formState != null) {
      if (!formState.validate()) return false;
    } else if (_immatCtrl.text.trim().isEmpty) {
      _showError('Veuillez saisir l\'immatriculation.');
      return false;
    }
    if (_typeActivite == null) {
      _showError("Veuillez sélectionner un type d'activité.");
      return false;
    }
    if (_typeVehicule == null) {
      _showError('Veuillez sélectionner un type de véhicule.');
      return false;
    }
    if (_marque == null) {
      _showError('Veuillez sélectionner une marque.');
      return false;
    }
    if (_modele == null) {
      _showError('Veuillez sélectionner un modèle.');
      return false;
    }
    if (_couleur == null) {
      _showError('Veuillez sélectionner une couleur.');
      return false;
    }
    if (_dateMiseEnCirculation == null) {
      _showError('Veuillez saisir la date de mise en circulation.');
      return false;
    }
    if (_dateEntreeFlotte == null) {
      _showError("Veuillez saisir la date d'entrée dans la flotte.");
      return false;
    }
    if (_dateMiseEnCirculation!.isAfter(_dateEntreeFlotte!)) {
      _showError(
          "La date de mise en circulation ne peut pas être postérieure à la date d'entrée dans la flotte.");
      return false;
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (_dateEntreeFlotte!.isAfter(todayDate)) {
      _showError(
          "La date d'entrée dans la flotte ne peut pas être postérieure à la date du jour.");
      return false;
    }
    return true;
  }

  // ── Groupe picker ─────────────────────────────────────────────────────────

  Future<void> _pickGroupe() async {
    final result = await Navigator.push<GroupeLocal>(
      context,
      MaterialPageRoute(builder: (_) => const GroupeSelectorPage()),
    );
    if (result == null || result.id == null) return;
    setState(() => _groupe = ReferentielItem(id: result.id!, nom: result.nom));
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_validateInformations()) {
      _tabCtrl.animateTo(0);
      return;
    }

    setState(() {
      _loading = true;
      _submitError = null;
    });

    final initial = widget.initial;
    final vehicule = Vehicule(
      id: initial?.id,
      immatriculation: _immatCtrl.text.trim(),
      marque: _marque?.nom ?? initial?.marque ?? '',
      modele: _modele?.nom ?? initial?.modele ?? '',
      marqueId: _marque?.id ?? initial?.marqueId,
      modeleId: _modele?.id ?? initial?.modeleId,
      typeVehiculeId: _typeVehicule?.id ?? initial?.typeVehiculeId,
      typeActiviteId: _typeActivite?.id ?? initial?.typeActiviteId,
      couleur: _couleur,
      kilometrage: initial?.kilometrage,
      statut: initial?.statut ?? 'DISPONIBLE',
      dateAchat: initial?.dateAchat,
      dateProchaineMaintenance: initial?.dateProchaineMaintenance,
      dateMiseEnCirculation: _dateMiseEnCirculation,
      dateEntreeFlotte: _dateEntreeFlotte,
      groupeId: _groupe?.id ?? initial?.groupeId,
      groupe: _groupe?.nom ?? initial?.groupe,
      numeroChassis: _chassisCtrl.text.trim().isEmpty
          ? null
          : _chassisCtrl.text.trim(),
      numeroTelephoneVehicule: _telVehiculeCtrl.text.trim().isEmpty
          ? null
          : _telVehiculeCtrl.text.trim(),
      numeroTelephoneBalise: _telBaliseCtrl.text.trim().isEmpty
          ? null
          : _telBaliseCtrl.text.trim(),
      identifiantBalise: _idBaliseCtrl.text.trim().isEmpty
          ? null
          : _idBaliseCtrl.text.trim(),
    );

    final notifier = ref.read(vehiculeNotifierProvider.notifier);
    final (error, vehiculeId) = _isEditing
        ? await notifier.updateVehicule(widget.initial!.id!, vehicule)
        : await notifier.createVehicule(vehicule);

    if (!mounted) return;
    final navigator = Navigator.of(context);
    setState(() => _loading = false);

    if (error != null) {
      final isConflict = error.toLowerCase().contains('immatriculation') ||
          error.toLowerCase().contains('déjà utilisée') ||
          error.toLowerCase().contains('déjà utilisé');
      if (isConflict) {
        setState(() => _immatError = error);
        _tabCtrl.animateTo(0);
        _formKey.currentState?.validate();
      }
      // Bandeau d'erreur persistant en haut du formulaire (en plus du toast).
      setState(() => _submitError = error);
      _appToast(context, error, type: _ToastType.error);
      return;
    }
    setState(() {
      _immatError = null;
      _submitError = null;
    });

    // En mode édition, on connaît déjà l'ID ; on ne dépend pas de la réponse PUT.
    final int? effectiveId =
        _isEditing ? (widget.initial?.id ?? vehiculeId) : vehiculeId;

    if (effectiveId != null) {
      final ds = ref.read(vehiculeDatasourceProvider);

      // Upload photos (best-effort)
      for (final photo in _photos) {
        try {
          final bytes = await photo.readAsBytes();
          await ds.uploadPhoto(effectiveId, bytes, photo.name);
        } catch (_) {}
      }

      // Upload des documents en attente (mode création, ou docs échoués en édition)
      if (_pendingDocuments.isNotEmpty) {
        final failedDocs = <String>[];
        String? docUploadError;
        for (final doc in _pendingDocuments) {
          try {
            await ds.uploadDocument(
              vehiculeId: effectiveId,
              typeDocumentId: doc.typeDocumentId,
              bytes: doc.bytes,
              filename: doc.filename,
              reference: doc.reference,
              dateEmission:
                  doc.dateEmission != null ? _isoDate(doc.dateEmission!) : null,
              dateExpiration: doc.dateExpiration != null
                  ? _isoDate(doc.dateExpiration!)
                  : null,
            );
          } catch (e) {
            failedDocs.add(doc.typeNom);
            // On retient le premier message explicite du backend
            // (ex. document trop volumineux).
            docUploadError ??= messageFromError(e, fallback: '');
          }
        }

        if (failedDocs.isNotEmpty && mounted) {
          _appToast(
            context,
            docUploadError != null && docUploadError.isNotEmpty
                ? docUploadError
                : (failedDocs.length == 1
                    ? 'Document "${failedDocs.first}" non envoyé.'
                    : '${failedDocs.length} documents non envoyés.'),
            type: _ToastType.warning,
            duration: const Duration(seconds: 5),
          );
        }
      }

      if (_isEditing) {
        ref.invalidate(documentsByVehiculeIdProvider(effectiveId));
      }
    }

    if (!mounted) return;

    if (_isEditing) {
      _appToast(context, 'Véhicule modifié avec succès.');
      navigator.pop();
    } else {
      _showSuccessDialog(
        vehiculeId: vehiculeId,
        vehiculeLabel: '${vehicule.immatriculation} - ${vehicule.displayName}',
      );
    }
  }

  void _showError(String message) =>
      _appToast(context, message, type: _ToastType.error);

  Future<void> _pickPhoto(int slot) async {
    final maxNew = _maxPhotos - _existingPhotos.length;
    if (slot >= _photos.length && _photos.length >= maxNew) return;
    final picked = await pickImageFromSource(context);
    if (picked == null) return;
    setState(() {
      if (slot < _photos.length) {
        _photos[slot] = picked;
      } else {
        _photos.add(picked);
      }
    });
  }

  void _removePhoto(int index) {
    setState(() => _photos.removeAt(index));
  }

  Future<void> _deleteExistingPhoto(int photoId) async {
    final vehiculeId = widget.initial?.id;
    if (vehiculeId == null) return;
    try {
      final ds = ref.read(vehiculeDatasourceProvider);
      await ds.deletePhoto(vehiculeId, photoId);
      setState(() => _existingPhotos.removeWhere((p) => p.id == photoId));
    } catch (_) {
      if (mounted) _showError('Impossible de supprimer cette photo.');
    }
  }

  void _openNewPhotoViewer(int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => _PhotoViewer(
        photos: _photos,
        initialIndex: index,
        onReplace: (i) {
          Navigator.pop(context);
          _pickPhoto(i);
        },
        onRemove: (i) {
          Navigator.pop(context);
          _removePhoto(i);
        },
      ),
    );
  }

  void _showSuccessDialog({required int? vehiculeId, required String vehiculeLabel}) {
    showDialog(
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
              'Véhicule créé !',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A2E)),
            ),
            const SizedBox(height: 8),
            Text(
              'Le véhicule a bien été ajouté à la flotte.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, color: Colors.grey.shade600, height: 1.4),
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
                onPressed: vehiculeId == null
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConfigurationVehiculePage(
                              vehiculeId: vehiculeId,
                              vehiculeLabel: vehiculeLabel,
                            ),
                          ),
                        );
                      },
                child: const Text('Configurer le véhicule',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: Text('Configurer plus tard',
                    style:
                        TextStyle(fontSize: 15, color: Colors.grey.shade600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Documents ─────────────────────────────────────────────────────────────

  Future<String?> _showArchivageConfirmDialog() async {
    final motifCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return AlertDialog(
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
                      fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
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
            actionsPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                    : () => Navigator.pop(ctx, motifCtrl.text.trim()),
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
          );
        });
      },
    );
    motifCtrl.dispose();
    return result;
  }

  Future<void> _deleteExistingDocument(int docId) async {
    final motif = await _showArchivageConfirmDialog();
    if (motif == null || !mounted) return;

    try {
      final ds = ref.read(vehiculeDatasourceProvider);
      await ds.archiverDocument(docId, motif);
      if (_isEditing && widget.initial?.id != null) {
        ref.invalidate(documentsByVehiculeIdProvider(widget.initial!.id!));
      }
      if (mounted) {
        _appToast(context, 'Document archivé.');
      }
    } catch (_) {
      if (mounted) _showError('Impossible de supprimer ce document.');
    }
  }

  // Upload immédiat d'un document (mode édition uniquement).
  Future<void> _uploadDocumentNow(_PendingDocument doc, int vehiculeId) async {
    setState(() => _loading = true);
    try {
      final ds = ref.read(vehiculeDatasourceProvider);
      await ds.uploadDocument(
        vehiculeId: vehiculeId,
        typeDocumentId: doc.typeDocumentId,
        bytes: doc.bytes,
        filename: doc.filename,
        reference: doc.reference,
        dateEmission:
            doc.dateEmission != null ? _isoDate(doc.dateEmission!) : null,
        dateExpiration:
            doc.permanent ? null : (doc.dateExpiration != null ? _isoDate(doc.dateExpiration!) : null),
        permanent: doc.permanent,
      );
      if (mounted) {
        ref.invalidate(documentsByVehiculeIdProvider(vehiculeId));
        _appToast(context, 'Document ajouté avec succès.');
      }
    } catch (e) {
      if (mounted) {
        _showError(messageFromError(e,
            fallback: "Impossible d'ajouter ce document, réessayez."));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showPendingDocDetail(int index, _PendingDocument doc) async {
    final types = ref.read(typesDocVehiculeProvider).value;
    if (types == null) {
      _showError('Chargement en cours, réessayez dans un instant.');
      return;
    }
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
    // En mode édition : upload immédiat et suppression du pending
    if (_isEditing && widget.initial?.id != null) {
      setState(() => _pendingDocuments.removeAt(index));
      await _uploadDocumentNow(result, widget.initial!.id!);
    } else {
      setState(() => _pendingDocuments[index] = result);
    }
  }

  Future<void> _showExistingDocDetail(DocumentVehiculeLocal doc) async {
    final types = ref.read(typesDocVehiculeProvider).value;
    if (types == null) {
      _showError('Chargement en cours, réessayez dans un instant.');
      return;
    }
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
            apiClient: ref.read(_vehiculeFormApiClientProvider),
          ),
    );
    if (result == null || !mounted) return;
    if (_isEditing && widget.initial?.id != null) {
      // Upload la nouvelle version puis supprime l'ancien document
      setState(() => _loading = true);
      try {
        final ds = ref.read(vehiculeDatasourceProvider);
        await ds.uploadDocument(
          vehiculeId: widget.initial!.id!,
          typeDocumentId: result.typeDocumentId,
          bytes: result.bytes,
          filename: result.filename,
          reference: result.reference,
          dateEmission:
              result.dateEmission != null ? _isoDate(result.dateEmission!) : null,
          dateExpiration:
              result.dateExpiration != null ? _isoDate(result.dateExpiration!) : null,
        );
        await ds.deleteDocument(doc.id);
        if (mounted) {
          ref.invalidate(documentsByVehiculeIdProvider(widget.initial!.id!));
          _appToast(context, 'Document mis à jour.');
        }
      } catch (e) {
        if (mounted) {
          _showError(messageFromError(e,
              fallback: 'Impossible de mettre à jour ce document.'));
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      setState(() => _pendingDocuments.add(result));
    }
  }

  Future<void> _showAddDocumentSheet() async {
    final types = ref.read(typesDocVehiculeProvider).value;
    if (types == null) {
      _showError('Chargement en cours, réessayez dans un instant.');
      return;
    }
    if (types.isEmpty) {
      _showError('Aucun type de document disponible.');
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
    // En mode édition : upload immédiat sans passer par le save du véhicule
    if (_isEditing && widget.initial?.id != null) {
      await _uploadDocumentNow(result, widget.initial!.id!);
    } else {
      setState(() => _pendingDocuments.add(result));
    }
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

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

  Widget _buildPhotosGrid() {
    final existingCount = _existingPhotos.length.clamp(0, _maxPhotos);
    return Row(
      children: List.generate(_maxPhotos, (i) {
        final isExisting = i < existingCount;
        final newIdx = i - existingCount;
        final isNew = !isExisting && newIdx < _photos.length;
        final isLast = i == _maxPhotos - 1;

        Widget slot;
        if (isExisting) {
          final photo = _existingPhotos[i];
          final urls = _existingPhotos.map((p) => p.url).toList();
          slot = GestureDetector(
            onTap: () => showNetworkPhotoViewer(
              context,
              urls: urls,
              initialIndex: i,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    photo.url,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                    errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Color(0xFFDDE1EA), size: 24)),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _deleteExistingPhoto(photo.id),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else if (isNew) {
          final photo = _photos[newIdx];
          slot = GestureDetector(
            onTap: () => _openNewPhotoViewer(newIdx),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<dynamic>(
                    future: photo.readAsBytes(),
                    builder: (_, snap) {
                      if (!snap.hasData) {
                        return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2));
                      }
                      return Image.memory(snap.data!, fit: BoxFit.cover);
                    },
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(newIdx),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          slot = GestureDetector(
            onTap: () => _pickPhoto(newIdx),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE3E6EE), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 24, color: Colors.grey.shade300),
                  const SizedBox(height: 4),
                  Text(
                    '${i + 1}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          );
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: AspectRatio(
              aspectRatio: 0.85,
              child: slot,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildInformationsTab({
    required AsyncValue<List<ReferentielItem>> typesVehiculesAsync,
    required AsyncValue<List<ReferentielItem>> typesActivitesAsync,
    required AsyncValue<List<ReferentielItem>> marquesAsync,
    required AsyncValue<List<ReferentielItem>> modelesAsync,
  }) {
    final couleurWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: _couleur,
          isExpanded: true,
          hint: const Text('Sélectionner',
              style: TextStyle(color: _kHint, fontSize: 15)),
          borderRadius: BorderRadius.circular(14),
          menuMaxHeight: 320,
          icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _kHint),
          onChanged: (v) => setState(() => _couleur = v),
          selectedItemBuilder: (context) => kVehiculeCouleurs.map((c) {
            final color = kVehiculeCouleurMap[c] ?? Colors.grey;
            final isLight = color.computeLuminance() > 0.85;
            return Row(children: [
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  border: Border.all(
                    color: isLight ? const Color(0xFFDDE1EA) : Colors.transparent,
                    width: 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(c, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, color: Colors.black87))),
            ]);
          }).toList(),
          items: kVehiculeCouleurs.map((c) {
            final color = kVehiculeCouleurMap[c] ?? Colors.grey;
            final isLight = color.computeLuminance() > 0.85;
            return DropdownMenuItem<String?>(
              value: c,
              child: Row(children: [
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: color, shape: BoxShape.circle,
                    border: Border.all(
                      color: isLight ? const Color(0xFFDDE1EA) : Colors.transparent,
                      width: 1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(c, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15))),
              ]),
            );
          }).toList(),
        ),
      ),
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // ── Section 1 : Identité du véhicule ───────────────────────────
          _FormSectionCard(
            icon: Icons.directions_car_rounded,
            accent: AppColors.primary,
            title: 'Identité du véhicule',
            isRequired: true,
            isExpanded: _expandedSections.contains(0),
            summary: _vehiculeSummary,
            onToggle: () => _toggleSection(0),
            child: Column(children: [
              // Type activité / Type véhicule
              ResponsiveFieldRow(
                left: _LabeledField(
                  label: "Type d'activité", isRequired: true,
                  child: _DropdownField(
                    value: _typeActivite, hint: 'Activité',
                    asyncValue: typesActivitesAsync,
                    onChanged: (v) => setState(() => _typeActivite = v),
                  ),
                ),
                right: _LabeledField(
                  label: 'Type de véhicule', isRequired: true,
                  child: _DropdownField(
                    value: _typeVehicule, hint: 'Type',
                    asyncValue: typesVehiculesAsync,
                    disabled: _isEditing,
                    onChanged: (v) => setState(() {
                      _typeVehicule = v; _marque = null; _modele = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Marque / Modèle
              ResponsiveFieldRow(
                left: _LabeledField(
                  label: 'Marque', isRequired: true,
                  child: _DropdownField(
                    value: _marque, hint: 'Marque',
                    asyncValue: marquesAsync,
                    disabled: _isEditing || _typeVehicule == null,
                    onChanged: (v) => setState(() { _marque = v; _modele = null; }),
                  ),
                ),
                right: _LabeledField(
                  label: 'Modèle', isRequired: true,
                  child: _DropdownField(
                    value: _modele, hint: 'Modèle',
                    asyncValue: modelesAsync,
                    disabled: _isEditing || _typeVehicule == null || _marque == null,
                    onChanged: (v) => setState(() => _modele = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Immatriculation / Couleur
              ResponsiveFieldRow(
                left: _LabeledField(
                  label: 'Immatriculation', isRequired: true,
                  child: _PlainField(
                    controller: _immatCtrl,
                    hint: 'AB-123-CD',
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) {
                      if (_immatError != null) setState(() => _immatError = null);
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (_immatError != null) return _immatError;
                      return null;
                    },
                  ),
                ),
                right: _LabeledField(
                  label: 'Couleur', isRequired: true,
                  child: couleurWidget,
                ),
              ),
              const SizedBox(height: 12),
              // N° châssis / Tél. véhicule
              ResponsiveFieldRow(
                left: _LabeledField(
                  label: 'N° châssis',
                  child: _PlainField(
                    controller: _chassisCtrl,
                    hint: 'VF1AA000123456789',
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                right: _LabeledField(
                  label: 'Tél. véhicule',
                  child: _PlainField(
                    controller: _telVehiculeCtrl,
                    hint: '06 12 34 56 78',
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // ── Section 2 : Infos supplémentaires ─────────────────────────
          _FormSectionCard(
            icon: Icons.info_rounded,
            accent: const Color(0xFF0CA678),
            title: 'Infos supplémentaires',
            isRequired: true,
            isExpanded: _expandedSections.contains(1),
            summary: _infosSuppSummary,
            onToggle: () => _toggleSection(1),
            child: Column(children: [
              // Dates
              ResponsiveFieldRow(
                left: _LabeledField(
                  label: 'Mise en circulation', isRequired: true,
                  child: _DateField(
                    label: 'JJ/MM/AAAA',
                    value: _dateMiseEnCirculation,
                    formatter: _formatDate,
                    onTap: () => _pickDate(
                      initial: _dateMiseEnCirculation,
                      maxDate: _dateEntreeFlotte ?? DateTime.now(),
                      onPicked: (d) => setState(() => _dateMiseEnCirculation = d),
                    ),
                  ),
                ),
                right: _LabeledField(
                  label: "Entrée dans la flotte", isRequired: true,
                  child: _DateField(
                    label: 'JJ/MM/AAAA',
                    value: _dateEntreeFlotte,
                    formatter: _formatDate,
                    onTap: () => _pickDate(
                      initial: _dateEntreeFlotte,
                      minDate: _dateMiseEnCirculation,
                      maxDate: DateTime.now(),
                      onPicked: (d) => setState(() => _dateEntreeFlotte = d),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Tél. balise / ID balise
              ResponsiveFieldRow(
                left: _LabeledField(
                  label: 'Tél. balise',
                  child: _PlainField(
                    controller: _telBaliseCtrl,
                    hint: '06 12 34 56 78',
                    keyboardType: TextInputType.phone,
                  ),
                ),
                right: _LabeledField(
                  label: 'ID balise GPS',
                  child: _PlainField(
                    controller: _idBaliseCtrl,
                    hint: 'BAL-00123',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Groupe
              _LabeledField(
                label: 'Groupe du véhicule',
                child: _GroupePickerField(
                  groupe: _groupe,
                  onPick: _pickGroupe,
                  onClear: () => setState(() => _groupe = null),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // ── Photos (toujours visible) ───────────────────────────────────
          _PhotosCard(photosGrid: _buildPhotosGrid()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab({
    required AsyncValue<List<DocumentVehiculeLocal>> existingDocsAsync,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        // ── Documents existantes (mode édition) ───────────────────────────
        if (_isEditing) ...[
          const _SectionTitle('Documents enregistrées'),
          const SizedBox(height: 10),
          existingDocsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Impossible de charger les Documents.',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ),
            data: (docs) {
              if (docs.isEmpty && _pendingDocuments.isEmpty) {
                return _EmptyDocState();
              }
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Aucune pièce enregistrée.',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 13)),
                );
              }
              return Column(
                children: docs
                    .map((doc) => _ExistingDocCard(
                          doc: doc,
                          onDelete: () => _deleteExistingDocument(doc.id),
                          onTap: () => _showExistingDocDetail(doc),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 20),
        ],

        // ── Documents en attente ──────────────────────────────────────────
        if (_pendingDocuments.isNotEmpty) ...[
          const _SectionTitle('À enregistrer'),
          const SizedBox(height: 10),
          ..._pendingDocuments.asMap().entries.map(
                (e) => _PendingDocCard(
                  doc: e.value,
                  onRemove: () =>
                      setState(() => _pendingDocuments.removeAt(e.key)),
                  onTap: () => _showPendingDocDetail(e.key, e.value),
                ),
              ),
          const SizedBox(height: 20),
        ],

        // ── État vide (création) ────────────────────────────────────────
        if (!_isEditing && _pendingDocuments.isEmpty) ...[
          _EmptyDocState(),
          const SizedBox(height: 20),
        ],

        // ── Bouton ajouter ─────────────────────────────────────────────
        OutlinedButton.icon(
          onPressed: _showAddDocumentSheet,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter une pièce'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kPrimary,
            side: const BorderSide(color: _kPrimary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final typesVehiculesAsync = ref.watch(typesVehiculesProvider);
    final typesActivitesAsync = ref.watch(typesActivitesProvider);
    final marquesAsync = _typeVehicule != null
        ? ref.watch(marquesByTypeProvider(_typeVehicule!.id))
        : const AsyncValue<List<ReferentielItem>>.data([]);
    final modelesAsync = (_typeVehicule != null && _marque != null)
        ? ref.watch(
            modelesByTypeAndMarqueProvider((_typeVehicule!.id, _marque!.id)))
        : const AsyncValue<List<ReferentielItem>>.data([]);
    // Types documents (préchargés en arrière-plan dès l'ouverture de la page)
    ref.watch(typesDocVehiculeProvider);

    final existingDocsAsync = _isEditing && widget.initial?.id != null
        ? ref.watch(documentsByVehiculeIdProvider(widget.initial!.id!))
        : const AsyncValue<List<DocumentVehiculeLocal>>.data([]);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppHeader(
        title: _isEditing ? 'Modifier le véhicule' : 'Nouveau véhicule',
        action: !_hasChanges
            ? null
            : AppHeaderAction(
                icon: Icons.check_rounded,
                loading: _loading,
                onTap: _save,
              ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabBar(),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: AppErrorBanner(
                  message: _submitError!,
                  onClose: () => setState(() => _submitError = null),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _KeepAliveTab(
                    child: _buildInformationsTab(
                      typesVehiculesAsync: typesVehiculesAsync,
                      typesActivitesAsync: typesActivitesAsync,
                      marquesAsync: marquesAsync,
                      modelesAsync: modelesAsync,
                    ),
                  ),
                  _buildDocumentsTab(existingDocsAsync: existingDocsAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGETS LOCAUX — Communs
// ═══════════════════════════════════════════════════════════════════════════

// Garde l'onglet en mémoire même quand il n'est pas visible dans le TabBarView.
class _KeepAliveTab extends StatefulWidget {
  final Widget child;
  const _KeepAliveTab({required this.child});

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

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
            'Carte grise, assurance, contrôle technique…',
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

  const _PendingDocCard({required this.doc, required this.onRemove, this.onTap});

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
            child:
                const Icon(Icons.description_outlined, color: _kPrimary, size: 20),
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
                if (doc.reference != null && doc.reference!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Réf : ${doc.reference}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
                if (doc.dateExpiration != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Exp : ${doc.dateExpiration!.day.toString().padLeft(2, '0')}/${doc.dateExpiration!.month.toString().padLeft(2, '0')}/${doc.dateExpiration!.year}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
  final DocumentVehiculeLocal doc;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  const _ExistingDocCard(
      {required this.doc, required this.onDelete, this.onTap});

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doc.displayName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E)),
                      ),
                    ),
                  ],
                ),
                if (doc.dateEmission != null || doc.dateExpiration != null) ...[
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
  final DocumentVehiculeLocal? existingDoc;
  final ApiClient? apiClient;
  const _AddDocumentSheet(
      {required this.types, this.initialDoc, this.existingDoc, this.apiClient});

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
  bool _loadingFile = false;
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
      _permanent = existing.permanent;
      if (widget.apiClient != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadExistingFile());
      }
    }
  }

  Future<void> _loadExistingFile() async {
    final doc = widget.existingDoc!;
    setState(() => _loadingFile = true);
    try {
      final bytes = await widget.apiClient!
          .getBytes('/v1/documents/${doc.id}/download');
      if (mounted) {
        setState(() {
          _fileBytes = bytes;
          _fileName = doc.fichierNom ?? 'document';
          _loadingFile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingFile = false);
        _showInline('Impossible de charger le fichier : $e');
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
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E6EE),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: Colors.black87),
              title: const Text('Appareil photo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined, color: Colors.black87),
              title: const Text('Fichier (PDF, image)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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
      setState(() { _fileBytes = bytes; _fileName = name; });
    }
  }

  void _previewFile() {
    if (_fileBytes == null) return;
    showDialog(
      context: context,
      builder: (_) => _FilePreviewDialog(bytes: _fileBytes!, filename: _fileName!),
    );
  }

  void _confirm() {
    if (_selectedType == null) {
      _showInline('Sélectionnez un type de document.');
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
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
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
                _LabeledField(
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
                const SizedBox(height: 12),

                // Référence
                _LabeledField(
                  label: 'Référence',
                  isRequired: true,
                  child: _PlainField(
                    controller: _referenceCtrl,
                    hint: 'Ex : CGVT-2024-001',
                  ),
                ),
                const SizedBox(height: 12),

                // Permanent
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
                ResponsiveFieldRow(
                  left: _LabeledField(
                    label: "Date d'émission",
                    child: _DateField(
                      label: 'JJ/MM/AAAA',
                      value: _dateEmission,
                      formatter: _fmt,
                      onTap: () => _pickDate(
                        _dateEmission,
                        (d) => setState(() => _dateEmission = d),
                      ),
                    ),
                  ),
                  right: _permanent
                      ? null
                      : _LabeledField(
                          label: "Date d'expiration",
                          child: _DateField(
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
                const SizedBox(height: 12),

                // Fichier
                _LabeledField(
                  label: 'Fichier',
                  isRequired: true,
                  child: GestureDetector(
                    onTap: _loadingFile
                        ? null
                        : (_fileBytes == null ? _pickFile : _previewFile),
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
                      child: _loadingFile
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _kPrimary,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Chargement du fichier…',
                                  style: TextStyle(
                                      fontSize: 15, color: _kHint),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Icon(
                                  _fileBytes != null
                                      ? Icons.check_circle_outline
                                      : Icons.attach_file,
                                  size: 18,
                                  color:
                                      _fileBytes != null ? _kPrimary : _kHint,
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
                                if (_fileBytes != null) ...[
                                  GestureDetector(
                                    onTap: _pickFile,
                                    child: Icon(Icons.edit_outlined,
                                        size: 16,
                                        color: Colors.grey.shade400),
                                  )
                                ],
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
                        (widget.initialDoc != null || widget.existingDoc != null)
                            ? 'Modifier'
                            : 'Ajouter',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
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

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGETS LOCAUX — Formulaire (inchangés)
// ═══════════════════════════════════════════════════════════════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

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

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isRequired;
  const _LabeledField(
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
            : _FieldLabel(label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PhotoViewer extends StatefulWidget {
  final List<XFile> photos;
  final int initialIndex;
  final void Function(int index) onReplace;
  final void Function(int index) onRemove;

  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.onReplace,
    required this.onRemove,
  });

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
          decoration: const BoxDecoration(color: Color(0xFF1A1A2E)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    Text(
                      'Photo ${_current + 1} sur ${widget.photos.length}',
                      style: const TextStyle(
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
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: widget.photos.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: FutureBuilder<dynamic>(
                      future: widget.photos[i].readAsBytes(),
                      builder: (_, snap) {
                        if (!snap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white54, strokeWidth: 2),
                          );
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: InteractiveViewer(
                            child:
                                Image.memory(snap.data!, fit: BoxFit.contain),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (widget.photos.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.photos.length, (i) {
                      final active = i == _current;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: active ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active ? _kPrimary : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onReplace(_current),
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => widget.onRemove(_current),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dialog aperçu fichier ─────────────────────────────────────────────────

class _FilePreviewDialog extends StatefulWidget {
  final Uint8List bytes;
  final String filename;

  const _FilePreviewDialog({required this.bytes, required this.filename});

  @override
  State<_FilePreviewDialog> createState() => _FilePreviewDialogState();
}

class _FilePreviewDialogState extends State<_FilePreviewDialog> {
  PdfController? _pdfController;
  bool _pdfLoading = false;
  bool _pdfError = false;

  static bool _isBytesPdf(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46;

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
                constraints: const BoxConstraints(
                    minHeight: 180, maxHeight: 420),
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
                                        style: TextStyle(color: Colors.white38)),
                                  )
                                : PdfView(
                                    controller: _pdfController!,
                                    scrollDirection: Axis.vertical,
                                    pageSnapping: false,
                                    backgroundDecoration: const BoxDecoration(
                                      color: Color(0xFF12122A),
                                    ),
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

class _DropdownField extends StatelessWidget {
  final ReferentielItem? value;
  final String hint;
  final AsyncValue<List<ReferentielItem>> asyncValue;
  final ValueChanged<ReferentielItem?> onChanged;
  final bool disabled;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.asyncValue,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = asyncValue is AsyncLoading;
    final items = asyncValue.value ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: disabled ? const Color(0xFFEDEEF1) : _kFieldFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: isLoading
            ? SizedBox(
                height: 50,
                child: Row(children: [
                  Expanded(
                    child: Text(hint,
                        style:
                            const TextStyle(color: _kHint, fontSize: 15)),
                  ),
                  SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.8, color: Colors.grey.shade400),
                  ),
                ]),
              )
            : DropdownButton<ReferentielItem?>(
                value: value,
                isExpanded: true,
                hint: Text(hint,
                    style: const TextStyle(color: _kHint, fontSize: 15)),
                borderRadius: BorderRadius.circular(14),
                menuMaxHeight: 320,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: disabled ? Colors.grey.shade300 : _kHint,
                ),
                onChanged: disabled ? null : onChanged,
                items: items
                    .map((item) => DropdownMenuItem<ReferentielItem?>(
                          value: item,
                          child: Text(item.nom,
                              style: const TextStyle(fontSize: 15)),
                        ))
                    .toList(),
              ),
      ),
    );
  }
}

class _PlainField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _PlainField({
    required this.controller,
    required this.hint,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 15, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kHint, fontSize: 15),
        filled: true,
        fillColor: _kFieldFill,
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
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String Function(DateTime) formatter;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? formatter(value!) : label,
                style: TextStyle(
                  fontSize: 15,
                  color: hasValue ? Colors.black87 : _kHint,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: _kHint,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section accordéon ─────────────────────────────────────────────────────────

class _FormSectionCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final bool isRequired;
  final bool isExpanded;
  final String? summary;
  final Widget child;
  final VoidCallback onToggle;

  const _FormSectionCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.isRequired,
    required this.isExpanded,
    required this.summary,
    required this.child,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                  child: Row(children: [
                    // Icône — même style que "Photos du véhicule"
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // Titre + résumé ou badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A2E),
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (isRequired)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F0),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Requis',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFE03131),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              )
                            else if (!isRequired)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Optionnel',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ),
                          ]),
                          if (!isExpanded && summary != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Chevron animé
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            // ── Contenu animé ────────────────────────────────────────────
            ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: isExpanded ? 1.0 : 0.0,
                child: Column(children: [
                  Divider(height: 1, color: Colors.grey.shade100),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    child: child,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photos card ───────────────────────────────────────────────────────────────

class _PhotosCard extends StatelessWidget {
  final Widget photosGrid;
  const _PhotosCard({required this.photosGrid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6EE)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF546E7A).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  color: Color(0xFF546E7A), size: 20),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                'Photos du véhicule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                'Optionnel · 4 photos maximum',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ]),
          ]),
          const SizedBox(height: 14),
          photosGrid,
        ],
      ),
    );
  }
}

// ── Sélecteur de groupe ───────────────────────────────────────────────────────

class _GroupePickerField extends StatelessWidget {
  final ReferentielItem? groupe;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _GroupePickerField({
    required this.groupe,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                groupe?.nom ?? 'Sélectionner un groupe',
                style: TextStyle(
                  fontSize: 15,
                  color: groupe != null ? Colors.black87 : _kHint,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (groupe != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close_rounded,
                    size: 18, color: _kHint),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 20, color: _kHint),
          ],
        ),
      ),
    );
  }
}
