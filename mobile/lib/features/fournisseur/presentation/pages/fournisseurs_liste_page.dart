import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/fournisseur.dart';
import '../providers/fournisseur_providers.dart';
import 'fournisseur_form_page.dart';

/// Référentiel des fournisseurs.
///
/// Un fournisseur ne se supprime pas — il a un historique comptable — il se
/// désactive : il disparaît alors des listes de saisie sans que ses factures
/// passées ne bougent.
class FournisseursListePage extends ConsumerStatefulWidget {
  const FournisseursListePage({super.key});

  @override
  ConsumerState<FournisseursListePage> createState() =>
      _FournisseursListePageState();
}

class _FournisseursListePageState extends ConsumerState<FournisseursListePage> {
  bool _actifsSeulement = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(fournisseursProvider(_actifsSeulement));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Fournisseurs',
        action: AppHeaderAction(
          icon: Icons.add_rounded,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FournisseurFormPage()),
            );
            ref.invalidate(fournisseursProvider);
          },
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Masquer les fournisseurs désactivés',
                      style: TextStyle(fontSize: 12.5, color: AppColors.label)),
                ),
                Switch(
                  value: _actifsSeulement,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _actifsSeulement = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text('$e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.label)),
              ),
              data: (liste) => liste.isEmpty
                  ? const Center(
                      child: Text('Aucun fournisseur',
                          style: TextStyle(color: AppColors.label)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: liste.length,
                      itemBuilder: (_, i) => _FournisseurCard(
                        fournisseur: liste[i],
                        onChanged: () => ref.invalidate(fournisseursProvider),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FournisseurCard extends ConsumerWidget {
  final Fournisseur fournisseur;
  final VoidCallback onChanged;
  const _FournisseurCard({required this.fournisseur, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fournisseur.nom,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: fournisseur.actif
                            ? AppColors.dark
                            : AppColors.hint)),
                const SizedBox(height: 2),
                Text(
                    [
                      fournisseur.type.label,
                      if (fournisseur.telephone?.isNotEmpty == true)
                        fournisseur.telephone!,
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: AppColors.hint)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: AppColors.label),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => FournisseurFormPage(initial: fournisseur)),
              );
              onChanged();
            },
          ),
          Switch(
            value: fournisseur.actif,
            activeThumbColor: AppColors.primary,
            onChanged: (v) async {
              await ref
                  .read(fournisseurDatasourceProvider)
                  .changerActivation(fournisseur.id!, v);
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}
