import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../data/parametrage_api.dart';
import '../providers/parametrage_providers.dart';
import 'referentiel_form_page.dart';

/// Liste générique des valeurs d'un référentiel, pilotée par son descripteur :
/// affichage, activation/désactivation, édition et suppression.
class ReferentielListePage extends ConsumerStatefulWidget {
  final ReferentielDescriptor descriptor;
  const ReferentielListePage({super.key, required this.descriptor});

  @override
  ConsumerState<ReferentielListePage> createState() =>
      _ReferentielListePageState();
}

class _ReferentielListePageState extends ConsumerState<ReferentielListePage> {
  ReferentielDescriptor get d => widget.descriptor;
  bool _busy = false;

  Future<void> _ouvrirFormulaire([Map<String, dynamic>? item]) async {
    final modifie = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ReferentielFormPage(descriptor: d, item: item),
      ),
    );
    if (modifie == true) ref.invalidate(referentielItemsProvider(d.endpoint));
  }

  Future<void> _basculerActif(Map<String, dynamic> item, bool actif) async {
    setState(() => _busy = true);
    try {
      await ref.read(parametrageApiProvider).changerActivation(
            d.endpoint, item[d.idField] as Object, actif);
      ref.invalidate(referentielItemsProvider(d.endpoint));
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _supprimer(Map<String, dynamic> item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Supprimer « ${_titre(item)} » ? Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(parametrageApiProvider)
          .supprimer(d.endpoint, item[d.idField] as Object);
      ref.invalidate(referentielItemsProvider(d.endpoint));
      _toast('« ${_titre(item)} » supprimé.');
    } catch (e) {
      _toast(_message(e), erreur: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _titre(Map<String, dynamic> item) {
    final champ = d.champTitre;
    if (champ == null) return '#${item[d.idField]}';
    return _valeur(item, champ).isEmpty ? '#${item[d.idField]}' : _valeur(item, champ);
  }

  /// Valeur affichable d'un champ pour un item (gère les références imbriquées).
  String _valeur(Map<String, dynamic> item, ChampDescriptor champ) {
    if (champ.type == 'reference') {
      final nested = champ.nom.endsWith('Id')
          ? champ.nom.substring(0, champ.nom.length - 2)
          : champ.nom;
      final obj = item[nested];
      if (obj is Map) {
        return (obj['nom'] ?? obj['libelle'] ?? obj['code'] ?? '').toString();
      }
      return item[champ.nom]?.toString() ?? '';
    }
    return item[champ.nom]?.toString() ?? '';
  }

  String _sousTitre(Map<String, dynamic> item) {
    final champ = d.champTitre;
    return d.champsSaisis
        .where((c) => c != champ && c.type != 'bool')
        .map((c) => _valeur(item, c))
        .where((v) => v.isNotEmpty)
        .join(' · ');
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
    return 'Opération impossible.';
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(referentielItemsProvider(d.endpoint));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(title: d.libelle),
      floatingActionButton: d.editable
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : () => _ouvrirFormulaire(),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter'),
            )
          : null,
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.hint),
                const SizedBox(height: 12),
                const Text('Chargement impossible.',
                    style: TextStyle(color: AppColors.label)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(referentielItemsProvider(d.endpoint)),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (liste) => liste.isEmpty
            ? const Center(
                child: Text('Aucune valeur. Ajoutez-en une.',
                    style: TextStyle(color: AppColors.label)))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: liste.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _tuile(liste[i]),
              ),
      ),
    );
  }

  Widget _tuile(Map<String, dynamic> item) {
    final actif = item['actif'] as bool? ?? true;
    final sousTitre = _sousTitre(item);

    return Opacity(
      opacity: actif ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: InkWell(
          onTap: d.editable ? () => _ouvrirFormulaire(item) : null,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_titre(item),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark)),
                      if (sousTitre.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(sousTitre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.label)),
                      ],
                    ],
                  ),
                ),
                if (d.gereActif && d.editable)
                  Switch.adaptive(
                    value: actif,
                    activeThumbColor: AppColors.primary,
                    onChanged: _busy ? null : (v) => _basculerActif(item, v),
                  ),
                if (d.editable)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.hint, size: 20),
                    onSelected: (v) {
                      if (v == 'edit') _ouvrirFormulaire(item);
                      if (v == 'delete') _supprimer(item);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Modifier')),
                      PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
