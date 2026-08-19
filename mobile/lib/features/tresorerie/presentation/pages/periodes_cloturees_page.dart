import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/rapports.dart';
import '../providers/tresorerie_providers.dart';

/// Mois déjà clôturés, et ce que vaut la trésorerie qu'ils publient.
///
/// Un mois clos archive sa trésorerie **arrêtée au dernier jour**, mais la
/// clôture ne réclame qu'un comptage tombant *quelque part* dans le mois : un
/// comptage le 3 valide les 31 jours. Le solde publié pouvait donc porter sur
/// une somme que personne n'avait vérifiée depuis des semaines, sans que rien
/// ne le dise.
///
/// Plutôt que de durcir l'exigence — au risque d'enfermer une exploitation dont
/// les saisies arrivent en retard —, cette page dit ce que la photo vaut : le
/// solde, sa date d'arrêté, et la date du comptage qui l'atteste. Le lecteur
/// juge lui-même de l'écart entre les deux.
class PeriodesClotureesPage extends ConsumerWidget {
  const PeriodesClotureesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClotures = ref.watch(cloturesPeriodeProvider);

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Périodes clôturées'),
      body: asyncClotures.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Impossible de charger les périodes',
                  style: TextStyle(color: Colors.grey.shade600)),
              TextButton.icon(
                onPressed: () => ref.invalidate(cloturesPeriodeProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
        data: (clotures) {
          if (clotures.isEmpty) return const _AucunePeriode();
          // Du plus récent au plus ancien : c'est le dernier mois publié qu'on
          // vient relire, pas le premier.
          final tri = [...clotures]..sort((a, b) => b.annee != a.annee
              ? b.annee.compareTo(a.annee)
              : b.mois.compareTo(a.mois));
          return RefreshIndicator(
            onRefresh: () => ref.refresh(cloturesPeriodeProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                const _NoteAttestation(),
                const SizedBox(height: 12),
                for (final c in tri) ...[
                  _CartePeriode(cloture: c),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoteAttestation extends StatelessWidget {
  const _NoteAttestation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: AppColors.hint),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Un mois clos ne bouge plus : les chiffres ci-dessous sont ceux '
              'qui ont été publiés. Chaque solde porte la date du comptage qui '
              'l\'atteste — plus elle est proche de la fin du mois, plus le '
              'solde publié a été vérifié de près.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.35, color: AppColors.label),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un mois clos, dépliable sur la justification de sa trésorerie.
class _CartePeriode extends ConsumerWidget {
  final CloturePeriodeData cloture;
  const _CartePeriode({required this.cloture});

  static const _mois = [
    'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
    'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
  ];

  /// Dernier jour du mois : la date à laquelle la trésorerie est arrêtée.
  DateTime get _finPeriode =>
      DateTime(cloture.annee, cloture.mois + 1, 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libelle = '${_mois[cloture.mois - 1]} ${cloture.annee}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // La ligne de séparation par défaut d'ExpansionTile double la bordure
        // de la carte.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: const Icon(Icons.lock_clock_rounded,
              size: 20, color: AppColors.primary),
          title: Text(
            libelle[0].toUpperCase() + libelle.substring(1),
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.dark),
          ),
          subtitle: Text(
            'Clôturé le ${DateFormat('dd/MM/yyyy').format(cloture.dateCloture)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.hint),
          ),
          children: [
            _SoldesArchives(
              annee: cloture.annee,
              mois: cloture.mois,
              finPeriode: _finPeriode,
            ),
          ],
        ),
      ),
    );
  }
}

/// Trésorerie publiée du mois, compte par compte. Chargée au dépliage : rien ne
/// justifie d'interroger le serveur pour des mois que personne n'ouvrira.
class _SoldesArchives extends ConsumerWidget {
  final int annee;
  final int mois;
  final DateTime finPeriode;

  const _SoldesArchives(
      {required this.annee, required this.mois, required this.finPeriode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSoldes =
        ref.watch(soldesClotureProvider((annee: annee, mois: mois)));

    return asyncSoldes.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.2)),
        ),
      ),
      error: (e, _) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Détail indisponible',
            style: TextStyle(fontSize: 12.5, color: AppColors.hint)),
      ),
      data: (soldes) {
        if (soldes.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Cette clôture est antérieure à l\'archivage du détail par '
              'compte : seuls ses états globaux ont été conservés.',
              style: TextStyle(
                  fontSize: 12.5, height: 1.35, color: AppColors.hint),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Trésorerie arrêtée au ${DateFormat('dd/MM/yyyy').format(finPeriode)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.hint),
            ),
            const SizedBox(height: 8),
            for (final s in soldes)
              _LigneSolde(solde: s, finPeriode: finPeriode),
          ],
        );
      },
    );
  }
}

class _LigneSolde extends StatelessWidget {
  final SoldeClotureData solde;
  final DateTime finPeriode;

  const _LigneSolde({required this.solde, required this.finPeriode});

  /// Nombre de jours entre le comptage et l'arrêté : c'est l'étendue non
  /// vérifiée du solde publié.
  int? get _joursSansComptage {
    final comptage = solde.dateDernierComptage;
    if (comptage == null) return null;
    return finPeriode.difference(comptage).inDays;
  }

  /// Vert quand l'arrêté est compté ou presque, ambre quand l'écart devient
  /// notable, rouge quand rien n'atteste le solde publié.
  Color get _couleur {
    final jours = _joursSansComptage;
    if (jours == null) return AppColors.error;
    if (jours <= 3) return AppColors.success;
    if (jours <= 10) return AppColors.warning;
    return AppColors.error;
  }

  String get _attestation {
    final comptage = solde.dateDernierComptage;
    if (comptage == null) {
      return 'Aucun comptage : ce solde n\'est attesté par aucun contrôle';
    }
    final jours = _joursSansComptage!;
    final date = DateFormat('dd/MM/yyyy').format(comptage);
    if (jours <= 0) return 'Attesté par le comptage du $date, jour de l\'arrêté';
    return 'Attesté par le comptage du $date, '
        '${jours == 1 ? '1 jour' : '$jours jours'} avant l\'arrêté';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(Icons.circle, size: 8, color: _couleur),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(solde.libelleCompte,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(_attestation,
                    style: TextStyle(
                        fontSize: 11.5, height: 1.3, color: _couleur)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(solde.solde),
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.dark),
          ),
        ],
      ),
    );
  }
}

class _AucunePeriode extends StatelessWidget {
  const _AucunePeriode();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_rounded,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            const Text('Aucun mois clôturé',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
            const SizedBox(height: 6),
            const Text(
              'Tant qu\'aucune période n\'est close, les états se recalculent '
              'à chaque consultation et peuvent donc changer.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, height: 1.4, color: AppColors.label),
            ),
          ],
        ),
      ),
    );
  }
}
