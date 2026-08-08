import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/partenaire.dart';
import '../providers/partenaire_providers.dart';
import 'partenaire_form_page.dart';

/// Facteur d'échelle des interrupteurs de la page.
///
/// Un [Switch] Material pèse lourd à côté d'un libellé de 12 px et d'une icône
/// de 18 px : réduit, il s'accorde à la ligne sans la dominer. Même valeur que
/// les bascules de `referentiel_liste_page`.
const double _kSwitchScale = 0.70;

/// Référentiel des partenaires.
///
/// Un partenaire ne se supprime pas — il a un historique comptable — il se
/// désactive : il disparaît alors des listes de saisie sans que ses factures
/// passées ne bougent.
class PartenairesListePage extends ConsumerStatefulWidget {
  const PartenairesListePage({super.key});

  @override
  ConsumerState<PartenairesListePage> createState() =>
      _PartenairesListePageState();
}

class _PartenairesListePageState extends ConsumerState<PartenairesListePage> {
  bool _actifsSeulement = true;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(partenairesProvider(_actifsSeulement));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Partenaires',
        action: AppHeaderAction(
          icon: Icons.add_rounded,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PartenaireFormPage()),
            );
            ref.invalidate(partenairesProvider);
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
                  child: Text('Masquer les partenaires désactivés',
                      style: TextStyle(fontSize: 12.5, color: AppColors.label)),
                ),
                Transform.scale(
                  scale: _kSwitchScale,
                  child: Switch(
                    value: _actifsSeulement,
                    activeThumbColor: AppColors.primary,
                    // Sans cela, le Switch réserve 48 px de haut : la ligne
                    // s'étirerait alors que l'interrupteur, lui, a rapetissé.
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (v) => setState(() => _actifsSeulement = v),
                  ),
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
                      child: Text('Aucun partenaire',
                          style: TextStyle(color: AppColors.label)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: liste.length,
                      itemBuilder: (_, i) => _PartenaireCard(
                        partenaire: liste[i],
                        onChanged: () => ref.invalidate(partenairesProvider),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartenaireCard extends ConsumerWidget {
  final Partenaire partenaire;
  final VoidCallback onChanged;
  const _PartenaireCard({required this.partenaire, required this.onChanged});

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
                Text(partenaire.nom,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: partenaire.actif
                            ? AppColors.dark
                            : AppColors.hint)),
                const SizedBox(height: 2),
                Text(
                    [
                      partenaire.typeNom,
                      if (partenaire.telephone?.isNotEmpty == true)
                        partenaire.telephone!,
                    ].join(' · '),
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.hint)),
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
                    builder: (_) => PartenaireFormPage(initial: partenaire)),
              );
              onChanged();
            },
          ),
          Transform.scale(
            scale: _kSwitchScale,
            child: Switch(
              value: partenaire.actif,
              activeThumbColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (v) async {
                await ref
                    .read(partenaireDatasourceProvider)
                    .changerActivation(partenaire.id!, v);
                onChanged();
              },
            ),
          ),
        ],
      ),
    );
  }
}
