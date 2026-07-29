import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/facture_fournisseur.dart';
import '../providers/fournisseur_providers.dart';
import '../widgets/facture_dialogs.dart';
import 'facture_detail_page.dart';
import 'facture_form_page.dart';
import 'fournisseurs_liste_page.dart';

/// Onglet « Fournisseurs » : l'échéancier de ce qu'on doit.
///
/// Les factures en retard sont en tête — c'est ce qui doit sauter aux yeux —
/// puis viennent les échéances à venir, de la plus proche à la plus lointaine.
class FournisseursTab extends ConsumerWidget {
  const FournisseursTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(echeancierProvider(null));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FactureFormPage()),
        ),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        label: const Text('Facture',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Erreur(
          message: '$e',
          onRetry: () => ref.invalidate(echeancierProvider(null)),
        ),
        data: (factures) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(echeancierProvider(null)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _TotalDuCard(factures: factures),
              const SizedBox(height: 12),
              if (factures.isEmpty)
                const _Vide()
              else
                ...factures.map((f) => _FactureCard(facture: f)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ce que l'entreprise doit, avec la part déjà échue.
class _TotalDuCard extends StatelessWidget {
  final List<FactureFournisseur> factures;
  const _TotalDuCard({required this.factures});

  @override
  Widget build(BuildContext context) {
    final total = factures.fold<double>(0, (s, f) => s + f.restantDu);
    final enRetard = factures
        .where((f) => f.enRetard)
        .fold<double>(0, (s, f) => s + f.restantDu);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Dettes fournisseurs',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label)),
              ),
              // Le référentiel se gère à part : ici, on regarde ce qu'on doit.
              _LienFournisseurs(),
            ],
          ),
          const SizedBox(height: 6),
          Text(CurrencyFormatter.format(total),
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark)),
          if (enRetard > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFBE9E9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  'Dont ${CurrencyFormatter.format(enRetard)} en retard',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFB71C1C))),
            ),
          ],
          const SizedBox(height: 4),
          Text('${factures.length} facture(s) à payer',
              style: const TextStyle(fontSize: 11.5, color: AppColors.hint)),
        ],
      ),
    );
  }
}

class _LienFournisseurs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FournisseursListePage()),
      ),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.dark,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      icon: const Icon(Icons.store_outlined, size: 16),
      label: const Text('Fournisseurs', style: TextStyle(fontSize: 12)),
    );
  }
}

/// Une facture due : qui, combien, pour quand.
class _FactureCard extends ConsumerWidget {
  final FactureFournisseur facture;
  const _FactureCard({required this.facture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final retard = facture.joursDeRetard(DateTime.now());
    final couleur = facture.enRetard ? const Color(0xFFB71C1C) : AppColors.label;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => FactureDetailPage(factureId: facture.id!)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                  facture.enRetard
                      ? Icons.warning_amber_rounded
                      : Icons.schedule_rounded,
                  size: 18,
                  color: couleur),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(facture.fournisseurNom ?? 'Fournisseur',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dark)),
                  const SizedBox(height: 2),
                  Text(
                      [
                        if (facture.categorieLibelle != null)
                          facture.categorieLibelle!,
                        if (facture.vehiculeImmatriculation != null)
                          facture.vehiculeImmatriculation!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.hint)),
                  const SizedBox(height: 3),
                  Text(
                      retard > 0
                          ? 'En retard de $retard jour(s)'
                          : 'Échéance ${DateFormat('dd/MM/yyyy').format(facture.dateEcheance)}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              retard > 0 ? FontWeight.w600 : FontWeight.w400,
                          color: couleur)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyFormatter.format(facture.restantDu),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark)),
                // Le total n'est rappelé que s'il diffère du restant dû.
                if (facture.montantPaye > 0)
                  Text('sur ${CurrencyFormatter.format(facture.montant)}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.hint)),
                const SizedBox(height: 6),
                // Payer est le geste le plus fréquent : il reste à un clic.
                _BoutonRegler(facture: facture),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Raccourci de règlement, sans passer par le détail.
class _BoutonRegler extends ConsumerWidget {
  final FactureFournisseur facture;
  const _BoutonRegler({required this.facture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => showReglementFactureDialog(context, ref, facture),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Régler',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark)),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 40, color: AppColors.hint),
          SizedBox(height: 10),
          Text('Vous ne devez rien à vos fournisseurs',
              style: TextStyle(color: AppColors.label)),
          SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
                'Enregistrez une facture dès sa réception : la dépense compte '
                'pour le mois où le travail a été fait, et vous gardez la '
                'liste de ce qu\'il reste à payer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.hint, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Erreur extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Erreur({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.label)),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
