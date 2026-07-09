import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_header.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../chauffeur/presentation/pages/chauffeur_selector_page.dart';
import '../../data/models/apercu_import_model.dart';
import '../../data/models/contravention_model.dart';
import '../providers/contravention_provider.dart';

/// Écran de revue des contraventions extraites d'un relevé PDF. L'exploitant
/// ajuste le chauffeur proposé, exclut d'éventuelles lignes, puis confirme.
class ContraventionImportReviewPage extends ConsumerStatefulWidget {
  final ApercuImportModel apercu;
  const ContraventionImportReviewPage({super.key, required this.apercu});

  @override
  ConsumerState<ContraventionImportReviewPage> createState() =>
      _ContraventionImportReviewPageState();
}

class _ReviewItem {
  ContraventionModel data;
  bool inclus = true;
  _ReviewItem(this.data);
}

class _ContraventionImportReviewPageState
    extends ConsumerState<ContraventionImportReviewPage> {
  late final List<_ReviewItem> _items;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _items = widget.apercu.candidats
        .map((c) => _ReviewItem(c))
        .toList(growable: false);
  }

  int get _nbInclus => _items.where((i) => i.inclus).length;

  Future<void> _changerChauffeur(_ReviewItem item) async {
    final chauffeur = await Navigator.push<Chauffeur>(
      context,
      MaterialPageRoute(builder: (_) => const ChauffeurSelectorPage()),
    );
    if (chauffeur == null || chauffeur.id == null) return;
    setState(() {
      item.data = ContraventionModel.fromEntity(item.data.copyWith(
        chauffeurId: chauffeur.id,
        chauffeurNom: '${chauffeur.prenom} ${chauffeur.nom}'.trim(),
        statutRattachement: 'MANUEL',
      ));
    });
  }

  Future<void> _confirmer() async {
    final aEnvoyer = _items
        .where((i) => i.inclus)
        .map((i) => i.data)
        .toList(growable: false);
    if (aEnvoyer.isEmpty) return;

    setState(() => _loading = true);
    try {
      final res =
          await ref.read(contraventionImportProvider).confirmer(aEnvoyer);
      if (!mounted) return;
      final creees = res['contraventionsCreees'] ?? aEnvoyer.length;
      final rattachees = res['contraventionsRattachees'] ?? 0;
      _toast('$creees contravention(s) importée(s), '
          '$rattachees rattachée(s) à un chauffeur.');
      Navigator.pop(context);
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
    return "Échec de la confirmation de l'import.";
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.apercu;
    final bloque = a.vehiculeInconnu || a.vehiculeId == null;

    return Scaffold(
      appBar: const AppHeader(title: 'Revue de l\'import'),
      body: Column(
        children: [
          _enTete(a, bloque),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucune nouvelle contravention à importer '
                        '(toutes déjà enregistrées).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _carte(_items[i]),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: (_items.isEmpty || bloque)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  onPressed: (_nbInclus > 0 && !_loading) ? _confirmer : null,
                  icon: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: Text('Confirmer ($_nbInclus)'),
                ),
              ),
            ),
    );
  }

  Widget _enTete(ApercuImportModel a, bool bloque) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_car, size: 20),
              const SizedBox(width: 8),
              Text(
                a.vehiculeImmatriculation ?? a.plaque ?? 'Véhicule inconnu',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          if (bloque)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Plaque « ${a.plaque ?? '?'} » non reconnue : aucun véhicule '
                'correspondant. Import impossible.',
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          if (a.doublonsIgnores.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${a.doublonsIgnores.length} contravention(s) déjà enregistrée(s), '
                'ignorée(s).',
                style: const TextStyle(color: Colors.orange, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _carte(_ReviewItem item) {
    final c = item.data;
    final aRattacher = c.chauffeurId == null;
    final d = c.dateInfraction;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    final heure = c.heureInfraction?.substring(0, 5);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.inclus,
              onChanged: (v) => setState(() => item.inclus = v ?? true),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.typeInfraction ?? c.description ?? 'Infraction',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$dateStr${heure != null ? ' à $heure' : ''}'
                    '${c.vitesseRelevee != null ? ' • ${c.vitesseRelevee} km/h' : ''}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${c.montant.toStringAsFixed(0)} FCFA',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _changerChauffeur(item),
                    child: Row(
                      children: [
                        Icon(Icons.person,
                            size: 16,
                            color: aRattacher ? Colors.orange : Colors.blue),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            aRattacher
                                ? 'À rattacher — choisir un chauffeur'
                                : c.chauffeurNom ?? 'Chauffeur',
                            style: TextStyle(
                              color: aRattacher ? Colors.orange : Colors.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(Icons.edit, size: 14, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
