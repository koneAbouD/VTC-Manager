import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/ligne_card.dart';
import '../../../../core/widgets/liste_filtree.dart';
import '../../../../core/widgets/statut_style.dart';
import '../../domain/entities/ligne_cotisation.dart';
import '../providers/cotisation_providers.dart';

const _statutsCotisation = [
  StatutOption(value: 'EN_ATTENTE', label: 'En attente', color: Colors.orange),
  StatutOption(
      value: 'PARTIELLEMENT_ENCAISSE', label: 'Partiel', color: Colors.blue),
  StatutOption(value: 'SOLDEE', label: 'Soldée', color: Colors.green),
  StatutOption(value: 'ANNULEE', label: 'Annulée', color: Colors.grey),
];

class CotisationsPage extends ConsumerWidget {
  const CotisationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(titre: 'Cotisations'),
            Expanded(
              child: ListeFiltree<LigneCotisation>(
                valeur: ref.watch(cotisationsProvider),
                messageVide: 'Aucune cotisation pour le moment.',
                onRefresh: () async {
                  ref.invalidate(cotisationsProvider);
                  await ref.read(cotisationsProvider.future);
                },
                dateOf: (c) => DateTime.tryParse(c.date ?? ''),
                statutOf: (c) => c.statut,
                statuts: _statutsCotisation,
                rechercheOf: (c) =>
                    '${c.nom ?? ''} ${Fmt.money(c.montantDu)} ${Fmt.date(c.date)}',
                itemBuilder: (c) => _card(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(LigneCotisation c) {
    final (couleur, icone) = statutStyle(c.statut);
    final reste = c.montantRestant ?? 0;
    return LigneCard(
      icone: icone,
      couleur: couleur,
      titre: c.nom ?? 'Cotisation',
      sousTitre: 'Le ${Fmt.date(c.date)} • ${Fmt.money(c.montantDu)}',
      trailing: reste > 0
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Reste',
                    style: TextStyle(fontSize: 10, color: Colors.black45)),
                Text(Fmt.money(reste),
                    style: TextStyle(
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            )
          : const Icon(Icons.check_circle_rounded,
              color: Color(0xFF2E7D32), size: 22),
    );
  }
}
