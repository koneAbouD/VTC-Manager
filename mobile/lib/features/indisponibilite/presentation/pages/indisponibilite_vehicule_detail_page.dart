import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../domain/entities/indisponibilite_vehicule.dart';
import '../providers/indisponibilite_vehicule_provider.dart';
import '../providers/indisponibilite_vehicule_state.dart';
import 'indisponibilite_vehicule_form_page.dart';

/// Détail (lecture seule) d'une immobilisation véhicule.
class IndisponibiliteVehiculeDetailPage extends ConsumerWidget {
  final IndisponibiliteVehicule indisponibilite;
  const IndisponibiliteVehiculeDetailPage(
      {super.key, required this.indisponibilite});

  static (Color, String) statut(String? s) => switch (s) {
        'EN_COURS' => (const Color(0xFFE65100), 'En cours'),
        'PLANIFIEE' => (const Color(0xFF1565C0), 'Planifiée'),
        'TERMINEE' => (AppColors.primaryDark, 'Terminée'),
        'ANNULEE' => (const Color(0xFF616161), 'Annulée'),
        _ => (const Color(0xFF616161), s ?? '—'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indisponibiliteVehiculeNotifierProvider);
    final list = state is IndisponibiliteVehiculeLoaded
        ? state.indisponibilites
        : const <IndisponibiliteVehicule>[];
    final match = list.where((i) => i.id == indisponibilite.id);
    final indispo = match.isEmpty ? indisponibilite : match.first;

    final fmtLong = DateFormat('dd MMM yyyy', 'fr_FR');
    final (color, label) = statut(indispo.statut);

    final bool unJour = indispo.dateFin != null &&
        indispo.dateFin!.year == indispo.dateDebut.year &&
        indispo.dateFin!.month == indispo.dateDebut.month &&
        indispo.dateFin!.day == indispo.dateDebut.day;
    final periode = unJour
        ? 'Le ${fmtLong.format(indispo.dateDebut)}'
        : indispo.dateFin == null
            ? 'Depuis le ${fmtLong.format(indispo.dateDebut)}'
            : '${fmtLong.format(indispo.dateDebut)} → ${fmtLong.format(indispo.dateFin!)}';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppHeader(
        title: 'Détail immobilisation',
        action: indispo.isTerminee
            ? null
            : AppHeaderAction(
                icon: Icons.edit_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IndisponibiliteVehiculeFormPage(initial: indispo),
                  ),
                ),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.no_transfer_outlined, color: color, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    indispo.vehiculeLibelle ?? 'Véhicule',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.dark),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _InfoCard(children: [
            _Row('Véhicule', indispo.vehiculeLibelle ?? '—'),
            _Row('Période', periode),
            if (indispo.motif != null && indispo.motif!.isNotEmpty)
              _Row('Motif', indispo.motif!),
            if (indispo.commentaire != null && indispo.commentaire!.isNotEmpty)
              _Row('Commentaire', indispo.commentaire!),
          ]),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: Color(0xFFF57F17)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pendant l\'immobilisation, le véhicule est marqué comme immobilisé : '
                    'aucune recette, cotisation ni pénalité n\'est générée.',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.brown.shade800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.label, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.dark),
            ),
          ),
        ],
      ),
    );
  }
}
