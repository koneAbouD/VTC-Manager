import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/document_source_bottom_sheet.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/error_banner.dart';
import '../providers/contravention_provider.dart';
import 'reversement_review_page.dart';

/// Import d'une quittance de paiement de l'État (PDF) : analyse le document,
/// rapproche les contraventions puis ouvre l'écran de revue avant reversement.
/// Phase 1 = PDF natif (l'OCR photo viendra en Phase 2).
class ReversementImportPage extends ConsumerStatefulWidget {
  const ReversementImportPage({super.key});

  @override
  ConsumerState<ReversementImportPage> createState() =>
      _ReversementImportPageState();
}

class _ReversementImportPageState extends ConsumerState<ReversementImportPage> {
  Uint8List? _fileBytes;
  String? _fileName;
  bool _loading = false;
  String? _erreur;

  Future<void> _pickPdf() async {
    // Fichier PDF/image depuis les dossiers OU photo prise avec la caméra
    // (jpg/png/pdf → OCR côté serveur pour les scans).
    final doc = await pickDocumentFromSource(context);
    if (doc == null) return;
    if (doc.bytes.isEmpty) {
      setState(() => _erreur = 'Le fichier sélectionné est vide.');
      return;
    }
    setState(() {
      _fileBytes = doc.bytes;
      _fileName = doc.fileName;
      _erreur = null; // un nouveau fichier repart d'un état sain
    });
  }

  Future<void> _analyser() async {
    if (_fileBytes == null) return;
    setState(() {
      _loading = true;
      _erreur = null;
    });
    try {
      final apercu = await ref
          .read(reversementImportProvider)
          .importer(_fileBytes!, _fileName ?? 'quittance.pdf');
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReversementReviewPage(apercu: apercu),
        ),
      );
      if (mounted) Navigator.pop(context); // retour à la liste après revue
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erreur = messageFromError(
          e,
          fallback: "Échec de l'analyse de la quittance. Réessayez.",
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aUnFichier = _fileBytes != null;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Importer une quittance'),
      body: SafeArea(
        top: false, // l'en-tête gère déjà le haut ; on protège le bas
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Téléversez la quittance de paiement (PDF) délivrée par l\'État. '
                'Les contraventions réglées seront rapprochées de la base, puis '
                'vous confirmerez leur reversement.',
                style: TextStyle(
                    fontSize: 13.5, height: 1.4, color: AppColors.label),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _loading ? null : _pickPdf,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 34),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color:
                            aUnFichier ? AppColors.primary : AppColors.border,
                        width: aUnFichier ? 1.5 : 1),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: aUnFichier
                              ? AppColors.primaryTint
                              : AppColors.fieldFill,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          aUnFichier
                              ? Icons.picture_as_pdf_rounded
                              : Icons.upload_file_rounded,
                          size: 28,
                          color: aUnFichier
                              ? AppColors.primaryDark
                              : AppColors.hint,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        aUnFichier ? _fileName! : 'Choisir un PDF ou une photo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.dark),
                      ),
                      if (!aUnFichier) ...[
                        const SizedBox(height: 4),
                        const Text('Quittance QuiPux / DGI (PDF ou photo)',
                            style:
                                TextStyle(fontSize: 12, color: AppColors.hint)),
                      ],
                    ],
                  ),
                ),
              ),
              if (_erreur != null) ...[
                const SizedBox(height: 16),
                ErrorBanner(message: _erreur!),
              ],
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: (!aUnFichier || _loading) ? null : _analyser,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.border,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded, size: 18),
                  label: Text(_loading ? 'Analyse en cours…' : 'Analyser',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
