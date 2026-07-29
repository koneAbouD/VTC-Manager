import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../domain/entities/facture_fournisseur.dart';
import '../providers/fournisseur_providers.dart';
import '../widgets/facture_dialogs.dart';

/// Détail d'une facture : ce qu'on doit, ce qu'on a déjà payé, et quand.
///
/// L'historique des règlements est la pièce qui explique le restant dû — sans
/// lui, un montant partiel reste inexplicable.
class FactureDetailPage extends ConsumerWidget {
  final int factureId;
  const FactureDetailPage({super.key, required this.factureId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(factureProvider(factureId));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Facture'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.label)),
          ),
        ),
        data: (facture) => _Corps(facture: facture),
      ),
    );
  }
}

class _Corps extends ConsumerWidget {
  final FactureFournisseur facture;
  const _Corps({required this.facture});

  Future<void> _annuler(BuildContext context, WidgetRef ref) async {
    final motif = await showMotifAnnulationDialog(
      context,
      titre: 'Annuler la facture ?',
      message: 'La charge disparaîtra du résultat et la dette du bilan. '
          'Indiquez le motif.',
    );
    if (motif == null || !context.mounted) return;
    try {
      await ref
          .read(fournisseurDatasourceProvider)
          .annulerFacture(facture.id!, motif);
      if (!context.mounted) return;
      refreshFournisseurs(ref);
      refreshFinances(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture annulée')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reglements = ref.watch(reglementsFactureProvider(facture.id!));
    final retard = facture.joursDeRetard(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // ── Ce qu'il reste à payer, en tête : c'est la question du jour.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: facture.statut.estOuverte
                ? AppColors.surface
                : const Color(0xFFF2F5F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(facture.fournisseurNom ?? 'Fournisseur',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark)),
              const SizedBox(height: 2),
              Text(facture.reference ?? '',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.hint)),
              const SizedBox(height: 14),
              Text(
                  facture.statut.estOuverte
                      ? CurrencyFormatter.format(facture.restantDu)
                      : facture.statut.label,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark)),
              const SizedBox(height: 2),
              Text(facture.statut.estOuverte ? 'Restant dû' : 'Facture soldée',
                  style: const TextStyle(fontSize: 12, color: AppColors.label)),
              if (retard > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE9E9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('En retard de $retard jour(s)',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB71C1C))),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        _Bloc(
          titre: 'La facture',
          lignes: [
            ('Montant', CurrencyFormatter.format(facture.montant)),
            ('Déjà réglé', CurrencyFormatter.format(facture.montantPaye)),
            (
              'Date de la facture',
              DateFormat('dd/MM/yyyy').format(facture.dateFacture)
            ),
            (
              'Échéance',
              DateFormat('dd/MM/yyyy').format(facture.dateEcheance)
            ),
            if (facture.numeroPiece?.isNotEmpty == true)
              ('N° de pièce', facture.numeroPiece!),
            if (facture.categorieLibelle != null)
              ('Catégorie', facture.categorieLibelle!),
            if (facture.vehiculeImmatriculation != null)
              ('Véhicule', facture.vehiculeImmatriculation!),
          ],
        ),

        if (facture.description?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _Bloc(titre: 'Description', texte: facture.description!),
        ],

        if (facture.motifAnnulation?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _Bloc(
              titre: 'Motif d\'annulation',
              texte: facture.motifAnnulation!,
              accent: AppColors.error),
        ],

        const SizedBox(height: 12),
        // ── Historique : ce qui explique le restant dû.
        reglements.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (liste) => _Historique(reglements: liste),
        ),

        const SizedBox(height: 20),
        if (facture.statut.estOuverte) ...[
          FilledButton.icon(
            onPressed: () =>
                showReglementFactureDialog(context, ref, facture),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Régler cette facture',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 10),
          // L'annulation n'a de sens que sur une facture jamais réglée : au-delà,
          // il faut d'abord extourner le règlement.
          if (facture.montantPaye == 0)
            OutlinedButton.icon(
              onPressed: () => _annuler(context, ref),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.block_rounded, size: 18),
              label: const Text('Annuler la facture'),
            ),
        ],
      ],
    );
  }
}

class _Historique extends StatelessWidget {
  final List<ReglementFacture> reglements;
  const _Historique({required this.reglements});

  @override
  Widget build(BuildContext context) {
    if (reglements.isEmpty) {
      return const _Bloc(
          titre: 'Règlements', texte: 'Aucun règlement pour le moment.');
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Règlements',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.label)),
          const SizedBox(height: 10),
          ...reglements.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                        r.extourne
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: r.extourne ? AppColors.hint : AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(DateFormat('dd/MM/yyyy').format(r.date),
                              style: TextStyle(
                                  fontSize: 13,
                                  color: r.extourne
                                      ? AppColors.hint
                                      : AppColors.dark,
                                  decoration: r.extourne
                                      ? TextDecoration.lineThrough
                                      : null)),
                          if (r.modePaiement != null)
                            Text(
                                r.modePaiement == 'MOBILE_MONEY'
                                    ? 'Mobile money'
                                    : 'Espèces',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.hint)),
                        ],
                      ),
                    ),
                    Text(CurrencyFormatter.format(r.montant),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                r.extourne ? AppColors.hint : AppColors.dark,
                            decoration: r.extourne
                                ? TextDecoration.lineThrough
                                : null)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

/// Bloc d'information : soit une liste libellé/valeur, soit un texte libre.
class _Bloc extends StatelessWidget {
  final String titre;
  final List<(String, String)>? lignes;
  final String? texte;
  final Color? accent;

  const _Bloc({required this.titre, this.lignes, this.texte, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent ?? AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent ?? AppColors.label)),
          const SizedBox(height: 10),
          if (texte != null)
            Text(texte!,
                style: const TextStyle(fontSize: 13, color: AppColors.dark)),
          if (lignes != null)
            ...lignes!.map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(l.$1,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.label)),
                      ),
                      Text(l.$2,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.dark)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
