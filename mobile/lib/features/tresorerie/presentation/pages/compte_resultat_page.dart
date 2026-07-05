import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/month_filter_pill.dart';
import '../../domain/entities/rapports.dart';
import '../providers/tresorerie_providers.dart';

/// Compte de résultat de gestion en cascade, avec bascule Caisse/Engagement
/// et marge sur coûts variables par véhicule.
class CompteResultatPage extends ConsumerStatefulWidget {
  const CompteResultatPage({super.key});

  @override
  ConsumerState<CompteResultatPage> createState() => _CompteResultatPageState();
}

class _CompteResultatPageState extends ConsumerState<CompteResultatPage> {
  int _mois = DateTime.now().month;
  int _annee = DateTime.now().year;
  String _base = 'CAISSE';

  @override
  Widget build(BuildContext context) {
    final crParams = (annee: _annee, mois: _mois, base: _base);
    final margeParams = (annee: _annee, mois: _mois);
    final asyncCr = ref.watch(compteResultatProvider(crParams));
    final asyncMarges = ref.watch(margesVehiculesProvider(margeParams));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Compte de résultat'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildFiltres(),
          const SizedBox(height: 12),
          asyncCr.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _erreur('Impossible de charger le compte de résultat',
                () => ref.invalidate(compteResultatProvider(crParams))),
            data: (cr) => _CascadeCard(cr: cr, base: _base),
          ),
          const SizedBox(height: 20),
          const Text('Marge par véhicule',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark)),
          const SizedBox(height: 4),
          const Text(
            'Produits − charges variables, sans imputation des charges fixes',
            style: TextStyle(fontSize: 12, color: AppColors.label),
          ),
          const SizedBox(height: 8),
          asyncMarges.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => _erreur('Impossible de charger les marges',
                () => ref.invalidate(margesVehiculesProvider(margeParams))),
            data: (marges) => marges.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Aucune opération rattachée à un véhicule sur la période',
                        style: TextStyle(fontSize: 13, color: AppColors.label)),
                  )
                : Column(
                    children: [for (final m in marges) _MargeTile(m)],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltres() {
    return Row(
      children: [
        Expanded(
          child: MonthFilterPill(
            mois: _mois,
            annee: _annee,
            onChanged: (m, a) => setState(() {
              _mois = m;
              _annee = a;
            }),
          ),
        ),
        const SizedBox(width: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'ENGAGEMENT', label: Text('Dû')),
            ButtonSegment(value: 'CAISSE', label: Text('Caisse')),
          ],
          selected: {_base},
          onSelectionChanged: (s) => setState(() => _base = s.first),
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _erreur(String message, VoidCallback onRetry) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: Colors.grey.shade600)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Réessayer'),
        ),
      ],
    );
  }
}

class _CascadeCard extends StatelessWidget {
  final CompteResultatData cr;
  final String base;
  const _CascadeCard({required this.cr, required this.base});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Column(
        children: [
          _ligne('Produits d\'exploitation', cr.produitsExploitation,
              sousTitre: base == 'ENGAGEMENT'
                  ? 'Montants dus de la période (recettes, cotisations, pénalités)'
                  : 'Montants encaissés sur la période'),
          _ligne('− Charges variables', -cr.chargesVariables,
              sousTitre: 'Maintenance, pièces — varie avec le roulage',
              secondaire: true),
          _solde('= Marge sur coûts variables', cr.margeSurCoutsVariables),
          _ligne('− Charges fixes', -cr.chargesFixes,
              sousTitre: 'Assurance, patente, frais de structure',
              secondaire: true),
          _solde('= Excédent brut d\'exploitation', cr.excedentBrutExploitation),
          _ligne('− Amortissements véhicules', -cr.amortissements,
              sousTitre: 'Dotation linéaire (prix d\'achat / durée)',
              secondaire: true),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cr.resultatGestion >= 0
                  ? AppColors.primaryTint
                  : const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('= Résultat de gestion',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cr.resultatGestion >= 0
                            ? AppColors.primaryDark
                            : Colors.red.shade900)),
                Text(CurrencyFormatter.format(cr.resultatGestion),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cr.resultatGestion >= 0
                            ? AppColors.primaryDark
                            : Colors.red.shade900)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Pont vers la caisse (variation des créances)',
                    style: TextStyle(fontSize: 11.5, color: AppColors.label)),
              ),
              const SizedBox(width: 8),
              Text(CurrencyFormatter.format(cr.pontCreances),
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.label)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligne(String libelle, double montant,
      {String? sousTitre, bool secondaire = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(libelle,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: secondaire ? AppColors.label : AppColors.dark)),
              ),
              const SizedBox(width: 8),
              Text(CurrencyFormatter.format(montant),
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: secondaire ? AppColors.label : AppColors.dark)),
            ],
          ),
          if (sousTitre != null)
            Text(sousTitre,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.hint)),
        ],
      ),
    );
  }

  Widget _solde(String libelle, double montant) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.scaffold,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(libelle,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Text(CurrencyFormatter.format(montant),
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MargeTile extends StatelessWidget {
  final MargeVehiculeData marge;
  const _MargeTile(this.marge);

  @override
  Widget build(BuildContext context) {
    final negative = marge.marge < 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car_outlined,
              size: 18, color: AppColors.label),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(marge.immatriculation,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                Text(
                  '${CurrencyFormatter.format(marge.produits)} − '
                  '${CurrencyFormatter.format(marge.chargesVariables)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.label),
                ),
                if (marge.joursImmobilisation > 0)
                  Text(
                    'Immobilisé ${marge.joursImmobilisation} j sur la période',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ),
          Text(CurrencyFormatter.format(marge.marge),
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: negative ? Colors.red.shade900 : AppColors.primaryDark)),
        ],
      ),
    );
  }
}
