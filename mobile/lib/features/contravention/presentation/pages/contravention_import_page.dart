import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_header.dart';
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

  Future<void> _pickPdf() async {
    // PDF téléchargé (couche texte) OU photo/scan (jpg/png → OCR côté serveur).
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _fileBytes = file.bytes;
          _fileName = file.name;
        });
      }
    }
  }

  Future<void> _analyser() async {
    if (_fileBytes == null) return;
    setState(() => _loading = true);
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
      setState(() => _loading = false);
      _toast(_messageErreur(e), erreur: true);
    }
  }

  void _toast(String message, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: erreur ? Colors.red.shade700 : null,
    ));
  }

  String _messageErreur(Object e) {
    try {
      final m = (e as dynamic).message;
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return "Échec de l'analyse du relevé.";
  }

  @override
  Widget build(BuildContext context) {
    final aUnFichier = _fileBytes != null;
    return Scaffold(
      appBar: const AppHeader(title: 'Importer un relevé PDF'),
      body: Padding(
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
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: (aUnFichier && !_loading) ? _analyser : null,
              icon: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search),
              label: const Text('Analyser le relevé'),
            ),
          ],
        ),
      ),
    );
  }
}
