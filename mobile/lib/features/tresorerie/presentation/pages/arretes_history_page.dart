import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../domain/entities/compte_courant.dart';
import '../providers/tresorerie_providers.dart';
import 'arrete_detail_page.dart';

String fmtDate(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Historique des arrêtés de compte (le plus récent en premier), filtrable sur
/// le mois d'arrêté (la date affichée sur chaque ligne).
class ArretesHistoryPage extends ConsumerStatefulWidget {
  const ArretesHistoryPage({super.key});

  @override
  ConsumerState<ArretesHistoryPage> createState() => _ArretesHistoryPageState();
}

class _ArretesHistoryPageState extends ConsumerState<ArretesHistoryPage> {
  /// Mois d'arrêté filtré ; null = tout l'historique.
  int? _mois;
  int? _annee;

  ({int? annee, int? mois}) get _filtre => (annee: _annee, mois: _mois);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(arretesProvider(_filtre));
    return Scaffold(
      appBar: const AppHeader(title: 'Arrêtés de compte'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: MonthFilterPill(
                    mois: _mois,
                    annee: _annee,
                    onChanged: (m, a) => setState(() {
                      _mois = m;
                      _annee = a;
                    }),
                    onEfface: () => setState(() {
                      _mois = null;
                      _annee = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  async.maybeWhen(
                    data: (a) =>
                        '${a.length} arrêté${a.length > 1 ? 's' : ''}',
                    orElse: () => '',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppColors.hint),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(arretesProvider(_filtre).future),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [
                  const SizedBox(height: 120),
                  Center(
                      child: Text('Impossible de charger l\'historique',
                          style: TextStyle(color: Colors.grey.shade600))),
                ]),
                data: (arretes) {
                  if (arretes.isEmpty) {
                    return ListView(children: [
                      const SizedBox(height: 120),
                      Icon(Icons.receipt_long_outlined,
                          size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Center(
                          child: Text(
                              _mois == null
                                  ? 'Aucun arrêté enregistré'
                                  : 'Aucun arrêté sur ce mois',
                              style: TextStyle(
                                  fontSize: 15, color: Colors.grey.shade600))),
                    ]);
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: arretes.length,
                    itemBuilder: (_, i) => _ArreteTile(arrete: arretes[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArreteTile extends StatelessWidget {
  final ArreteCompte arrete;
  const _ArreteTile({required this.arrete});

  /// Libellé de la ligne : le chauffeur quand l'arrêté n'a qu'un bénéficiaire,
  /// sinon le véhicule qu'ils se partagent. La référence ne sert que de secours.
  String get _libelle {
    if (arrete.reglements.length == 1) {
      final nom = arrete.reglements.first.chauffeurNom;
      if (nom != null && nom.isNotEmpty) return nom;
    }
    final perimetre = arrete.perimetreLibelle;
    if (perimetre != null && perimetre.isNotEmpty) return perimetre;
    return arrete.reference ?? 'Arrêté #${arrete.id}';
  }

  @override
  Widget build(BuildContext context) {
    final annule = arrete.statut == 'ANNULE';
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ArreteDetailPage(id: arrete.id!))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.8)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryTint,
              child: Icon(
                  arrete.perimetre == 'VEHICULE'
                      ? Icons.directions_car_rounded
                      : Icons.person_rounded,
                  size: 18,
                  color: AppColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          decoration:
                              annule ? TextDecoration.lineThrough : null,
                          color: AppColors.dark)),
                  const SizedBox(height: 2),
                  Text('${fmtDate(arrete.dateArrete)} · '
                      '${arrete.reglements.length} bénéficiaire${arrete.reglements.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.label)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(arrete.totalRestitue),
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade800)),
                const SizedBox(height: 2),
                const Text('restitué', style: TextStyle(fontSize: 10.5, color: AppColors.hint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
