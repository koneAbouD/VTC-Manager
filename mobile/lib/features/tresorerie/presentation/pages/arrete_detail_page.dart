import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/bytes_downloader.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../domain/entities/compte_courant.dart';
import '../providers/tresorerie_providers.dart';
import 'arretes_history_page.dart' show fmtDate;

/// Détail d'un arrêté : en-tête, synthèse, règlements par bénéficiaire et
/// lignes snapshot (cotisations créditées, créances compensées). Permet le
/// téléchargement du décompte PDF et l'annulation (avec motif).
class ArreteDetailPage extends ConsumerWidget {
  final int id;
  const ArreteDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(arreteDetailProvider(id));
    final arrete = async.valueOrNull;
    final annulable = arrete != null && arrete.statut == 'VALIDE';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail de l\'arrêté'),
        actions: [
          IconButton(
            tooltip: 'Télécharger le décompte (PDF)',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: arrete == null ? null : () => _telechargerPdf(context, ref),
          ),
          if (annulable)
            IconButton(
              tooltip: 'Annuler l\'arrêté',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _annuler(context, ref),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('Impossible de charger l\'arrêté',
                style: TextStyle(color: Colors.grey.shade600))),
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            _Entete(arrete: a),
            const SizedBox(height: 12),
            _Synthese(arrete: a),
            const SizedBox(height: 16),
            const _Section('Règlements'),
            for (final r in a.reglements) _ReglementTile(reglement: r),
            const SizedBox(height: 16),
            const _Section('Lignes de l\'arrêté'),
            for (final l in a.lignes) _LigneTile(ligne: l),
          ],
        ),
      ),
    );
  }

  Future<void> _telechargerPdf(BuildContext context, WidgetRef ref) async {
    try {
      final bytes =
          await ref.read(tresorerieDatasourceProvider).getArretePdf(id);
      final path = await downloadBytesFile(
          bytes, 'decompte_arrete_$id.pdf', 'application/pdf');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Décompte téléchargé${path != null ? '\n$path' : ''}')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Échec du téléchargement : $e')));
      }
    }
  }

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(
      context,
      titre: 'Annuler l\'arrêté ?',
      message: 'Toutes les écritures de cet arrêté seront contre-passées : '
          'créances rouvertes, restitution annulée, cotisations rendues. '
          'Indiquez le motif.',
    );
    if (motif == null) return;
    try {
      await ref.read(tresorerieDatasourceProvider).annulerArrete(id, motif);
      ref.invalidate(arreteDetailProvider(id));
      ref.invalidate(arretesProvider);
      ref.invalidate(balanceAgeeProvider);
      ref.invalidate(balanceAgeeVehiculeProvider);
      ref.invalidate(tresorerieSummaryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Arrêté annulé')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Annulation refusée : $e')));
      }
    }
  }
}

class _Entete extends StatelessWidget {
  final ArreteCompte arrete;
  const _Entete({required this.arrete});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.primaryTint, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(arrete.reference ?? 'Arrêté #${arrete.id}',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          Text(
              '${arrete.perimetre == 'VEHICULE' ? 'Véhicule' : 'Chauffeur'}'
              '${arrete.perimetreLibelle != null ? ' · ${arrete.perimetreLibelle}' : ''}',
              style: const TextStyle(fontSize: 12.5, color: AppColors.primaryDark)),
          const SizedBox(height: 2),
          Text(
              'Période ${fmtDate(arrete.periodeDebut)} → ${fmtDate(arrete.periodeFin)}'
              ' · arrêté le ${fmtDate(arrete.dateArrete)}',
              style: const TextStyle(fontSize: 12, color: AppColors.primaryDark)),
          if (arrete.estAnnule) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  'ARRÊTÉ ANNULÉ'
                  '${arrete.motifAnnulation != null ? ' — ${arrete.motifAnnulation}' : ''}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade900)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Synthese extends StatelessWidget {
  final ArreteCompte arrete;
  const _Synthese({required this.arrete});
  @override
  Widget build(BuildContext context) {
    final fonds =
        arrete.reglements.fold<double>(0, (s, r) => s + r.totalCotisations);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Column(
        children: [
          _row('Fonds de cotisation', fonds, AppColors.dark),
          const Divider(height: 18),
          _row('− Créances compensées', arrete.totalCompense,
              Colors.orange.shade900),
          if (arrete.totalReliquat > 0)
            _row('Reliquat reporté', arrete.totalReliquat, Colors.red.shade900),
          const Divider(height: 18),
          _row('= Net restitué', arrete.totalRestitue, Colors.green.shade800,
              gras: true),
        ],
      ),
    );
  }

  Widget _row(String label, double montant, Color couleur, {bool gras = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: gras ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.dark)),
          Text(CurrencyFormatter.format(montant),
              style: TextStyle(
                  fontSize: gras ? 15 : 13,
                  fontWeight: gras ? FontWeight.w700 : FontWeight.w600,
                  color: couleur)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  const _Section(this.titre);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(titre,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.label)),
    );
  }
}

class _ReglementTile extends StatelessWidget {
  final ReglementArrete reglement;
  const _ReglementTile({required this.reglement});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reglement.chauffeurNom ?? 'Chauffeur #${reglement.chauffeurId}',
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dark)),
                const SizedBox(height: 2),
                Text(
                    'compensé ${CurrencyFormatter.format(reglement.totalCreancesCompensees)}'
                    '${reglement.reliquatReporte > 0 ? ' · reliquat ${CurrencyFormatter.format(reglement.reliquatReporte)}' : ''}'
                    '${reglement.modePaiement != null ? ' · ${reglement.modePaiement == 'MOBILE_MONEY' ? 'Mobile Money' : 'Espèces'}' : ''}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.label)),
              ],
            ),
          ),
          Text(CurrencyFormatter.format(reglement.montantNet),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: reglement.aRestitution
                      ? Colors.green.shade800
                      : AppColors.hint)),
        ],
      ),
    );
  }
}

class _LigneTile extends StatelessWidget {
  final LigneArrete ligne;
  const _LigneTile({required this.ligne});

  String get _label => switch (ligne.document) {
        'COTISATION' => 'Cotisation',
        'RECETTE' => 'Recette',
        'PENALITE' => 'Pénalité',
        'CONTRAVENTION' => 'Contravention',
        _ => ligne.document,
      };

  @override
  Widget build(BuildContext context) {
    final credit = ligne.estCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Icon(credit ? Icons.savings_rounded : Icons.receipt_long_rounded,
              size: 16, color: credit ? Colors.green.shade700 : Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$_label #${ligne.documentId}',
                style: const TextStyle(fontSize: 13, color: AppColors.dark)),
          ),
          Text('${credit ? '+' : '−'} ${CurrencyFormatter.format(ligne.montant)}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: credit ? Colors.green.shade800 : Colors.orange.shade900)),
        ],
      ),
    );
  }
}
