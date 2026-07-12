import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../domain/entities/compte_courant.dart';
import '../providers/tresorerie_providers.dart';
import 'arrete_form_page.dart';
import 'arretes_history_page.dart';
import 'releve_chauffeur_page.dart';

/// Restitution des cotisations : soldes de compte courant (fonds − créances),
/// au choix **par chauffeur** ou **par véhicule**. Un tap ouvre l'arrêté de compte.
class ComptesCourantsPage extends ConsumerStatefulWidget {
  const ComptesCourantsPage({super.key});

  @override
  ConsumerState<ComptesCourantsPage> createState() =>
      _ComptesCourantsPageState();
}

class _ComptesCourantsPageState extends ConsumerState<ComptesCourantsPage> {
  /// false = par chauffeur, true = par véhicule.
  bool _parVehicule = false;

  String get _perimetre => _parVehicule ? 'VEHICULE' : 'CHAUFFEUR';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(comptesCourantsProvider(_perimetre));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restitution des cotisations'),
        actions: [
          IconButton(
            tooltip: 'Arrêter tout le mois',
            icon: const Icon(Icons.playlist_add_check_rounded),
            onPressed: _arreterBatch,
          ),
          IconButton(
            tooltip: 'Historique des arrêtés',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArretesHistoryPage())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(comptesCourantsProvider(_perimetre).future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Error(
              onRetry: () => ref.invalidate(comptesCourantsProvider(_perimetre))),
          data: (comptes) {
            final totalFonds = comptes.fold<double>(0, (s, c) => s + c.fondsCotisation);
            final totalNet = comptes.fold<double>(0, (s, c) => s + (c.net > 0 ? c.net : 0));
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _EnteteCard(
                  totalFonds: totalFonds,
                  totalNet: totalNet,
                  parVehicule: _parVehicule,
                  onToggle: () => setState(() => _parVehicule = !_parVehicule),
                ),
                const SizedBox(height: 8),
                if (comptes.isEmpty)
                  const _Empty()
                else
                  for (final c in comptes)
                    _CompteRow(
                      compte: c,
                      parVehicule: _parVehicule,
                      onTap: () => _ouvrirArrete(c),
                      onLongPress: _parVehicule
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReleveChauffeurPage(
                                      chauffeurId: c.tiersId, nom: c.libelle),
                                ),
                              ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _ouvrirArrete(CompteCourant compte) async {
    final fait = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ArreteFormPage(
          perimetre: _perimetre,
          perimetreId: compte.tiersId,
          libelle: compte.libelle,
        ),
      ),
    );
    if (fait == true) {
      ref.invalidate(comptesCourantsProvider(_perimetre));
    }
  }

  Future<void> _arreterBatch() async {
    final precedent = DateTime(DateTime.now().year, DateTime.now().month - 1);
    var annee = precedent.year;
    var mois = precedent.month;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Arrêter tout le mois',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MonthFilterPill(
                mois: mois,
                annee: annee,
                onChanged: (m, a) => setState(() {
                  mois = m;
                  annee = a;
                }),
              ),
              const SizedBox(height: 12),
              Text(
                  'Arrête le compte de tous les chauffeurs ayant un fonds sur '
                  'la période. Le net positif est restitué en espèces.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Arrêter')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final debut = DateTime(annee, mois, 1);
    final fin = DateTime(annee, mois + 1, 0);
    try {
      final arretes = await ref.read(tresorerieDatasourceProvider).arreterBatch(
            periodeDebut: debut,
            periodeFin: fin,
            modePaiement: 'ESPECES',
          );
      ref.invalidate(comptesCourantsProvider(_perimetre));
      ref.invalidate(arretesProvider);
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(tresorerieSummaryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${arretes.length} arrêté(s) enregistré(s)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec de l\'arrêté en lot : $e')));
      }
    }
  }
}

class _EnteteCard extends StatelessWidget {
  final double totalFonds;
  final double totalNet;
  final bool parVehicule;
  final VoidCallback onToggle;
  const _EnteteCard(
      {required this.totalFonds,
      required this.totalNet,
      required this.parVehicule,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Fonds de cotisation détenu',
                    style: TextStyle(fontSize: 13, color: AppColors.primaryDark)),
              ),
              InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(parVehicule ? 'Par véhicule' : 'Par chauffeur',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark)),
                      const Icon(Icons.arrow_drop_down,
                          size: 18, color: AppColors.primaryDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(CurrencyFormatter.format(totalFonds),
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark)),
          if (totalNet > 0) ...[
            const SizedBox(height: 4),
            Text('dont ${CurrencyFormatter.format(totalNet)} restituables (net des créances)',
                style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
          ],
        ],
      ),
    );
  }
}

class _CompteRow extends StatelessWidget {
  final CompteCourant compte;
  final bool parVehicule;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _CompteRow(
      {required this.compte,
      required this.parVehicule,
      required this.onTap,
      this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final crediteur = compte.net > 0;
    final (netBg, netFg) = crediteur
        ? (const Color(0xFFE8F5E9), Colors.green.shade800)
        : (const Color(0xFFFDECEA), Colors.red.shade900);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.6)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppColors.primaryTint,
              child: Icon(
                  parVehicule
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
                  Text(compte.libelle,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark)),
                  const SizedBox(height: 2),
                  Text(
                      'Fonds ${CurrencyFormatter.format(compte.fondsCotisation)}'
                      ' · Créances ${CurrencyFormatter.format(compte.totalCreances)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.label)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: netBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(CurrencyFormatter.format(compte.net),
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: netFg)),
                ),
                const SizedBox(height: 3),
                Text(crediteur ? 'à restituer' : 'reste dû',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.hint)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('Aucun fonds de cotisation en cours',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final VoidCallback onRetry;
  const _Error({required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      const SizedBox(height: 120),
      Center(
          child: Text('Impossible de charger les comptes courants',
              style: TextStyle(color: Colors.grey.shade600))),
      Center(
        child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer')),
      ),
    ]);
  }
}
