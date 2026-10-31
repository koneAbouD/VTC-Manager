import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tmk_cache/tmk_cache.dart';

import '../../../../core/network/session_manager.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/image_viewer.dart';
import '../providers/parametrage_providers.dart';

/// Image d'une valeur de référentiel : zone d'ajout, aperçu plein cadre avec
/// « changer » et « supprimer », état de téléversement.
///
/// Le fichier part aussitôt choisi vers `{endpoint}/image` ; [onChanged] reçoit
/// le nom d'objet à enregistrer avec la valeur et l'URL d'aperçu (tous deux
/// nuls quand l'image est retirée). Partagé par le formulaire générique et les
/// formulaires dédiés du paramétrage.
class ChampImageReferentiel extends ConsumerStatefulWidget {
  final String endpoint;

  /// Titre de la visionneuse plein écran.
  final String titre;
  final String? previewUrl;
  final void Function(String? image, String? url) onChanged;
  final void Function(String message) onErreur;

  /// Fond teinté de l'accent sur la zone d'ajout ; false : fond neutre.
  final bool fondTeinte;

  const ChampImageReferentiel({
    super.key,
    required this.endpoint,
    required this.titre,
    required this.previewUrl,
    required this.onChanged,
    required this.onErreur,
    this.fondTeinte = true,
  });

  @override
  ConsumerState<ChampImageReferentiel> createState() =>
      _ChampImageReferentielState();
}

class _ChampImageReferentielState extends ConsumerState<ChampImageReferentiel> {
  bool _uploading = false;

  Color get _fieldFill => AppColors.fieldFill;

  Future<void> _choisirImage() async {
    final XFile? picked = await SessionManager.instance.sortieAttendue(
      () => ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        imageQuality: 85,
      ),
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final res = await ref
          .read(parametrageApiProvider)
          .uploaderImage(widget.endpoint, bytes, picked.name);
      if (!mounted) return;
      widget.onChanged(res.image, res.url);
    } catch (e) {
      widget.onErreur(_message(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  String _message(Object e) {
    try {
      final m = (e as dynamic).message;
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return 'Téléversement impossible.';
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.previewUrl;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _uploading
          ? _imageUploading()
          : preview == null
              ? _imageDropzone()
              : _imageRempli(preview),
    );
  }

  /// État vide : zone d'ajout élégante, entièrement cliquable.
  Widget _imageDropzone() {
    return GestureDetector(
      onTap: _choisirImage,
      child: Container(
        height: 172,
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.fondTeinte ? null : _fieldFill,
          gradient: widget.fondTeinte
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryTint, _fieldFill],
                )
              : null,
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
              child: Icon(Icons.add_photo_alternate_rounded,
                  size: 27, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text('Ajouter une image',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark)),
            const SizedBox(height: 3),
            Text('JPG ou PNG · appuyez pour parcourir',
                style: TextStyle(fontSize: 12, color: AppColors.label)),
          ],
        ),
      ),
    );
  }

  /// Image présente : plein cadre, ombre douce, actions flottantes superposées.
  Widget _imageRempli(String preview) {
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
              onTap: () => showImageViewer(context, preview, titre: widget.titre),
              child: Image(
                image: imageReseau(preview),
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: _fieldFill,
                    child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: _fieldFill,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: AppColors.hint, size: 30),
                        const SizedBox(height: 6),
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
                    onTap: _choisirImage,
                  ),
                  const SizedBox(width: 8),
                  _actionFlottante(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Supprimer',
                    couleur: AppColors.error,
                    onTap: () => widget.onChanged(null, null),
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
        color: _fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            const SizedBox(height: 12),
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
    Color? couleur,
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
            child: Icon(icon, size: 19, color: couleur ?? AppColors.dark),
          ),
        ),
      ),
    );
  }
}
