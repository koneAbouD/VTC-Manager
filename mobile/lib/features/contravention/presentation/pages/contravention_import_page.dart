import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/document_source_bottom_sheet.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/error_banner.dart';
import '../providers/contravention_provider.dart';
import 'contravention_import_review_page.dart';

/// Mode 1 — téléversement d'un relevé de contraventions PDF (Ministère des
/// Transports / CGI). Analyse le PDF puis ouvre l'écran de revue.
class ContraventionImportPage extends ConsumerStatefulWidget {
  const ContraventionImportPage({super.key});

  @override
  ConsumerState<ContraventionImportPage> createState() =>
      _ContraventionImportPageState();
}

class _ContraventionImportPageState
    extends ConsumerState<ContraventionImportPage> {
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
          .read(contraventionImportProvider)
          .importer(_fileBytes!, _fileName ?? 'releve.pdf');
      if (!mounted) return;
      setState(() => _loading = false);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContraventionImportReviewPage(apercu: apercu),
        ),
      );
      if (mounted) Navigator.pop(context); // retour à la liste après revue
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _erreur = messageFromError(
          e,
          fallback: "Échec de l'analyse du relevé. Réessayez.",
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final aUnFichier = _fileBytes != null;
    return Scaffold(
      appBar: const AppHeader(title: 'Importer un relevé PDF'),
      body: SafeArea(
        top: false, // l'en-tête gère déjà le haut ; on protège le bas
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Téléversez le relevé de contraventions (PDF) du Ministère des '
                'Transports. Les infractions seront extraites et le chauffeur '
                'proposé selon le programme de travail.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _loading ? null : _pickPdf,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        aUnFichier ? Icons.picture_as_pdf : Icons.upload_file,
                        size: 48,
                        color: aUnFichier ? Colors.red.shade400 : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        aUnFichier ? _fileName! : 'Choisir un PDF ou une photo',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (aUnFichier)
                        TextButton(
                          onPressed: _loading ? null : _pickPdf,
                          child: const Text('Changer de fichier'),
                        ),
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
                  label: Text(
                      _loading ? 'Analyse en cours…' : 'Analyser le relevé',
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
