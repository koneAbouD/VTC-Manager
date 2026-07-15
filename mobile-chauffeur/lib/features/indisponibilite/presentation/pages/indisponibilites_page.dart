import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/ligne_card.dart';
import '../../../../core/widgets/liste_filtree.dart';
import '../../../../core/widgets/statut_style.dart';
import '../../domain/entities/indisponibilite.dart';
import '../providers/indisponibilite_providers.dart';
import 'indisponibilite_form_page.dart';

const _statutsIndispo = [
  StatutOption(value: 'PLANIFIEE', label: 'Planifiée', color: Colors.orange),
  StatutOption(value: 'EN_COURS', label: 'En cours', color: Colors.blue),
  StatutOption(value: 'TERMINEE', label: 'Terminée', color: Colors.green),
  StatutOption(value: 'ANNULEE', label: 'Annulée', color: Colors.grey),
];

class IndisponibilitesPage extends ConsumerWidget {
  const IndisponibilitesPage({super.key});

  Future<void> _declarer(BuildContext context, WidgetRef ref) async {
    final cree = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const IndisponibiliteFormPage()));
    if (cree == true) {
      ref.invalidate(indisponibilitesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Indisponibilité déclarée.')));
      }
    }
  }

  Future<void> _terminer(BuildContext context, WidgetRef ref, int id) async {
    final result =
        await ref.read(terminerIndisponibiliteUseCaseProvider).call(id);
    if (!context.mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
      (_) {
        ref.invalidate(indisponibilitesProvider);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Indisponibilité terminée.')));
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              titre: 'Indisponibilités',
              actionIcon: Icons.add_rounded,
              onAction: () => _declarer(context, ref),
            ),
            Expanded(
              child: ListeFiltree<Indisponibilite>(
                valeur: ref.watch(indisponibilitesProvider),
                messageVide: 'Aucune indisponibilité déclarée.',
                onRefresh: () async {
                  ref.invalidate(indisponibilitesProvider);
                  await ref.read(indisponibilitesProvider.future);
                },
                dateOf: (i) => DateTime.tryParse(i.dateDebut ?? ''),
                statutOf: (i) => i.statut,
                statuts: _statutsIndispo,
                rechercheOf: (i) =>
                    '${i.motif ?? ''} ${i.remplacantNom ?? ''} ${Fmt.date(i.dateDebut)}',
                hintRecherche: 'Rechercher...',
                itemBuilder: (i) => _card(context, ref, i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Indisponibilite i) {
    final (couleur, icone) = statutStyle(i.statut);
    final periode = i.dateFin != null && i.dateFin != i.dateDebut
        ? 'Du ${Fmt.date(i.dateDebut)} au ${Fmt.date(i.dateFin)}'
        : 'Le ${Fmt.date(i.dateDebut)}';
    final sousTitre =
        i.remplacantNom != null ? '$periode • ${i.remplacantNom}' : periode;
    return LigneCard(
      icone: icone,
      couleur: couleur,
      titre: i.motif ?? 'Indisponibilité',
      sousTitre: sousTitre,
      trailing: i.estTerminable && i.id != null
          ? TextButton(
              onPressed: () => _terminer(context, ref, i.id!),
              style: TextButton.styleFrom(
                foregroundColor: couleur,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Terminer'),
            )
          : null,
    );
  }
}
