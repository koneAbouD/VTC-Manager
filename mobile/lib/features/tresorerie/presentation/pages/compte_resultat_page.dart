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

  /// Amortissement pris en compte dans la marge par véhicule. Activé par
  /// défaut : c'est la rentabilité réelle, une fois l'usure du véhicule payée.
  /// Le désactiver revient à la marge sur coûts variables, utile pour comparer
  /// l'exploitation de véhicules achetés à des prix très différents.
  bool _amorti = true;

  @override
  Widget build(BuildContext context) {
    final crParams = (annee: _annee, mois: _mois, base: _base);
    // La liste par véhicule est le découpage de la cascade : elle se lit dans la
    // même base, sinon les deux blocs de l'écran se contrediraient.
    final margeParams = (annee: _annee, mois: _mois, base: _base);
    final asyncCr = ref.watch(compteResultatProvider(crParams));
    final asyncMarges = ref.watch(margesVehiculesProvider(margeParams));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Compte de résultat'),
      body: ListView(
        // Padding bas incluant l'inset de la barre de navigation Android
        // (gestes / 3 boutons) pour que le dernier contenu ne passe pas dessous.
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 32 + MediaQuery.of(context).padding.bottom),
        children: [
          _buildFiltres(),
          const SizedBox(height: 12),
          asyncCr.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => _erreur(
                'Impossible de charger le compte de résultat',
                () => ref.invalidate(compteResultatProvider(crParams))),
            data: (cr) => _CascadeCard(cr: cr, base: _base),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text('Marge par véhicule',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
              ),
              _AmortiToggle(
                actif: _amorti,
                onChanged: (v) => setState(() => _amorti = v),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // La base est rappelée ici : deux véhicules identiques n'affichent pas
          // la même marge selon qu'on lit le dû ou l'encaissé.
          Text(
            '${_base == 'ENGAGEMENT' ? 'Produits dus' : 'Produits encaissés'} '
            '− charges variables${_amorti ? ' − amortissement' : ''}, '
            'sans imputation des charges fixes',
            style: const TextStyle(fontSize: 12, color: AppColors.label),
          ),
          const SizedBox(height: 8),
          asyncMarges.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => _erreur('Impossible de charger les marges',
                () => ref.invalidate(margesVehiculesProvider(margeParams))),
            data: (marges) => marges.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                        'Aucune opération rattachée à un véhicule sur la période',
                        style: TextStyle(fontSize: 13, color: AppColors.label)),
                  )
                : Column(
                    children: [
                      for (final m in marges) _MargeTile(m, amorti: _amorti)
                    ],
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

/// Bascule « Amorti » de la marge par véhicule : pastille verte quand la
/// dotation d'amortissement est retenue, grise quand elle est écartée.
class _AmortiToggle extends StatelessWidget {
  final bool actif;
  final ValueChanged<bool> onChanged;

  const _AmortiToggle({required this.actif, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: actif
          ? 'Amortissement inclus dans la marge'
          : 'Amortissement exclu de la marge',
      child: InkWell(
        onTap: () => onChanged(!actif),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: actif ? AppColors.primaryTint : AppColors.headerButton,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: actif ? AppColors.primary : AppColors.border,
                width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                actif
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                size: 14,
                color: actif ? AppColors.primaryDark : AppColors.label,
              ),
              const SizedBox(width: 6),
              Text('Amorti',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          actif ? AppColors.primaryDark : AppColors.label)),
            ],
          ),
        ),
      ),
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
          // Les cotisations sont un dépôt restitué en fin de période, pas un
          // produit : elles sont hors résultat dans les deux bases.
          _ligne('Produits d\'exploitation', cr.produitsExploitation,
              sousTitre: base == 'ENGAGEMENT'
                  ? 'Montants dus de la période (recettes, amendes)'
                  : 'Montants encaissés sur la période'),
          _ligne('− Charges variables', -cr.chargesVariables,
              sousTitre: 'Maintenance, pièces — varie avec le roulage',
              secondaire: true),
          _solde('= Marge sur coûts variables', cr.margeSurCoutsVariables),
          _ligne('− Charges fixes', -cr.chargesFixes,
              sousTitre: 'Assurance, patente, frais de structure',
              secondaire: true),
          _solde(
              '= Excédent brut d\'exploitation', cr.excedentBrutExploitation),
          _ligne('− Amortissements véhicules', -cr.amortissements,
              sousTitre: 'Dotation linéaire (prix d\'achat / durée)',
              secondaire: true),
          // Une reprise (créances qui rentrent) est un montant négatif : elle
          // s'ajoute au résultat, le libellé le dit alors explicitement.
          if (cr.dotationProvisions != 0)
            _ligne(
                cr.dotationProvisions >= 0
                    ? '− Provisions sur créances'
                    : '+ Reprise sur provisions',
                -cr.dotationProvisions,
                sousTitre: cr.dotationProvisions >= 0
                    ? 'Part des impayés qu\'on n\'espère plus recouvrer'
                    : 'Créances finalement encaissées',
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
              children: [
                Expanded(
                  child: Text('= Résultat de gestion',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: cr.resultatGestion >= 0
                              ? AppColors.primaryDark
                              : Colors.red.shade900)),
                ),
                const SizedBox(width: 8),
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
                style: const TextStyle(fontSize: 11, color: AppColors.hint)),
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
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MargeTile extends StatelessWidget {
  final MargeVehiculeData marge;

  /// Amortissement retenu dans la marge affichée (bascule « Amorti »).
  final bool amorti;

  const _MargeTile(this.marge, {required this.amorti});

  @override
  Widget build(BuildContext context) {
    // Rentabilité affichée = marge nette (après amortissement) quand la bascule
    // est active et qu'un amortissement s'applique ; sinon la marge sur coûts
    // variables. Les deux montants viennent du backend, rien n'est recalculé ici.
    final aAmortissement = amorti && marge.dotationAmortissement > 0;
    final valeurPrincipale = aAmortissement ? marge.margeNette : marge.marge;
    final negative = valeurPrincipale < 0;
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
                if (aAmortissement)
                  Text(
                    '− Amortissement '
                    '${CurrencyFormatter.format(marge.dotationAmortissement)}',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.label),
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
          Text(CurrencyFormatter.format(valeurPrincipale),
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color:
                      negative ? Colors.red.shade900 : AppColors.primaryDark)),
        ],
      ),
    );
  }
}
