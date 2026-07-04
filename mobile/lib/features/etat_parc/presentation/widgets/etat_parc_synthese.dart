import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vehicule/domain/entities/statut_vehicule.dart';
import '../../../vehicule/presentation/pages/vehicule_detail_page.dart';
import '../../../vehicule/presentation/providers/referentiel_provider.dart';
import '../../data/models/etat_parc_summary_model.dart';
import '../providers/etat_parc_provider.dart';
import 'etat_parc_filtre_sheet.dart';

/// Largeur à partir de laquelle on bascule en disposition « large »
/// (tablette / paysage) : KPI et alertes sur une seule rangée.
const double _kTabletBreakpoint = 600;

/// Synthèse de l'état de parc : en-tête, KPI (disponibilité, utilisation,
/// immobilisés), barre de répartition + légende, véhicules demandant une
/// action et alertes préventives.
///
/// La disposition est responsive : les KPI et les alertes se répartissent sur
/// une rangée en tablette et s'empilent en téléphone.
class EtatParcSynthese extends ConsumerWidget {
  const EtatParcSynthese({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(etatParcSummaryProvider);

    return summary.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => _ErreurSynthese(
        onRetry: () => ref.invalidate(etatParcSummaryProvider),
      ),
      data: (data) {
        // Décision téléphone / tablette sur la largeur d'écran réelle
        // (indépendante du padding de la liste parente).
        final isWide =
            MediaQuery.sizeOf(context).width >= _kTabletBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(isWide: isWide),
            const SizedBox(height: 14),
            _KpiSection(data: data, isWide: isWide),
            const SizedBox(height: 16),
            _BarLegende(data: data),
            if (data.exceptions.isNotEmpty) ...[
              const SizedBox(height: 18),
              _ExceptionsCard(exceptions: data.exceptions),
            ],
            if (data.alertes.hasAlertes) ...[
              const SizedBox(height: 18),
              _AlertesSection(alertes: data.alertes, isWide: isWide),
            ],
          ],
        );
      },
    );
  }
}

// ── En-tête ──────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final bool isWide;
  const _Header({required this.isWide});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(etatParcFiltreProvider);
    const title = Text(
      "État de parc — aujourd'hui",
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: Color(0xFF1A1A2E),
      ),
    );
    final actif = f.estActif;
    const vert = Color(0xFF43A047);
    final filtreBtn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showEtatParcFiltreSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: actif
                ? vert.withValues(alpha: 0.1)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: actif ? vert : Colors.grey.shade300),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded,
                  size: 14,
                  color: actif ? vert : Colors.grey.shade600),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Groupe : ${f.groupeLabel} · Activité : ${f.activiteLabel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: actif ? vert : Colors.grey.shade600,
                    fontWeight: actif ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: actif ? vert : Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: title),
          const SizedBox(width: 12),
          Flexible(child: filtreBtn),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: filtreBtn),
      ],
    );
  }
}

// ── Section KPI ──────────────────────────────────────────────────────────────

class _KpiSection extends StatelessWidget {
  final EtatParcSummaryModel data;
  final bool isWide;
  const _KpiSection({required this.data, required this.isWide});

  static Color _tauxColor(double taux) {
    if (taux >= 80) return const Color(0xFF2E7D32);
    if (taux >= 60) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  static String _pct(double v) =>
      '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} %';

  @override
  Widget build(BuildContext context) {
    // Immobilisés « anciens » : présents dans la liste d'exceptions au statut
    // IMMOBILISE depuis plus de 7 jours.
    final immobilisesAnciens = data.exceptions
        .where((e) =>
            e.statut == 'IMMOBILISE' && (e.joursDansStatut ?? 0) > 7)
        .length;

    final tiles = <Widget>[
      _KpiTile(
        label: 'Disponibilité opérationnelle',
        valeur: _pct(data.tauxDisponibilite),
        valeurColor: _tauxColor(data.tauxDisponibilite),
        sousLabel:
            '${data.enService + data.disponibles} / ${data.parcActif} véhicules actifs',
        horizontal: !isWide,
      ),
      _KpiTile(
        label: "Taux d'utilisation",
        valeur: _pct(data.tauxUtilisation),
        valeurColor: const Color(0xFF1A1A2E),
        sousLabel: '${data.enService} en service / ${data.parcActif} actifs',
        horizontal: !isWide,
      ),
      _KpiTile(
        label: 'Immobilisés',
        valeur: '${data.immobilises}',
        valeurColor: const Color(0xFFC62828),
        sousLabel: immobilisesAnciens > 0
            ? 'dont $immobilisesAnciens depuis plus de 7 j'
            : 'aucun depuis plus de 7 j',
        horizontal: !isWide,
      ),
    ];

    if (isWide) {
      // `IntrinsicHeight` borne la hauteur du `Row` : sans lui,
      // `CrossAxisAlignment.stretch` tenterait d'imposer la hauteur infinie
      // héritée du `ListView` parent et les cartes ne s'afficheraient pas.
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          tiles[i],
        ],
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String valeur;
  final Color valeurColor;
  final String sousLabel;

  /// En téléphone, disposition horizontale (libellés à gauche, valeur à
  /// droite) pour une carte pleine largeur ; en tablette, disposition
  /// verticale pour trois colonnes.
  final bool horizontal;

  const _KpiTile({
    required this.label,
    required this.valeur,
    required this.valeurColor,
    required this.sousLabel,
    required this.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.shade200),
    );

    if (horizontal) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: decoration,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey.shade700)),
                  const SizedBox(height: 2),
                  Text(sousLabel,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              valeur,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: valeurColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            valeur,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: valeurColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            sousLabel,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Barre de répartition + légende ───────────────────────────────────────────

class _BarLegende extends ConsumerWidget {
  final EtatParcSummaryModel data;
  const _BarLegende({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuts = ref.watch(statutsVehiculeResolvedProvider);
    Color couleurDe(String code) =>
        StatutVehicule.resolve(code, statuts).couleur;
    String libelleDe(String code) =>
        StatutVehicule.resolve(code, statuts).libelle;

    final entries = <(String, int, Color)>[
      (libelleDe('EN_SERVICE'), data.enService, couleurDe('EN_SERVICE')),
      (libelleDe('DISPONIBLE'), data.disponibles, couleurDe('DISPONIBLE')),
      (libelleDe('EN_MAINTENANCE'), data.enMaintenance,
          couleurDe('EN_MAINTENANCE')),
      (libelleDe('IMMOBILISE'), data.immobilises, couleurDe('IMMOBILISE')),
      (libelleDe('HORS_PARC'), data.horsParc, couleurDe('HORS_PARC')),
    ];

    final segments = entries.where((e) => e.$2 > 0).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (final s in segments)
                  Expanded(flex: s.$2, child: Container(color: s.$3)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final e in entries) _LegendeItem(label: e.$1, count: e.$2, color: e.$3),
          ],
        ),
      ],
    );
  }
}

class _LegendeItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _LegendeItem(
      {required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label ',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
              ),
              TextSpan(
                text: '$count',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Carte des exceptions (défilement interne) ────────────────────────────────

class _ExceptionsCard extends StatelessWidget {
  final List<VehiculeExceptionModel> exceptions;
  const _ExceptionsCard({required this.exceptions});

  /// Hauteur maximale de la zone de liste ; au-delà, elle défile.
  static const double _maxListHeight = 260;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Véhicules demandant une action',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _maxListHeight),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: exceptions.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 60, color: Colors.grey.shade100),
              itemBuilder: (_, i) => _ExceptionTile(exception: exceptions[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Ligne exception ──────────────────────────────────────────────────────────

class _ExceptionTile extends ConsumerWidget {
  final VehiculeExceptionModel exception;
  const _ExceptionTile({required this.exception});

  /// Icône dérivée du motif d'immobilisation / d'anomalie.
  static IconData _motifIcon(String? motif) => switch (motif) {
        'IMMOBILISATION_PENALITE' => Icons.gavel_rounded,
        'PANNE_OU_ACCIDENT' => Icons.car_crash_rounded,
        'MAINTENANCE_EN_COURS' => Icons.build_rounded,
        'SANS_CHAUFFEUR' => Icons.person_off_rounded,
        'SORTIE_PARC' => Icons.logout_rounded,
        'DECISION_MANUELLE' => Icons.pan_tool_rounded,
        _ => Icons.directions_car_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuts = ref.watch(statutsVehiculeResolvedProvider);
    final statut =
        StatutVehicule.resolve(exception.statut ?? '', statuts);
    final color = statut.couleur;
    final jours = exception.joursDansStatut;

    return InkWell(
      onTap: exception.vehiculeId == null
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      VehiculeDetailPage(vehiculeId: exception.vehiculeId!),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_motifIcon(exception.motif), size: 19, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    [
                      exception.immatriculation,
                      if (exception.libelleVehicule.isNotEmpty)
                        exception.libelleVehicule,
                    ].join(' · '),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${statut.libelle} — ${exception.motifLabel}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (jours != null) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  jours == 0 ? "aujourd'hui" : '$jours j',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Alertes préventives ──────────────────────────────────────────────────────

class _AlertesSection extends StatelessWidget {
  final EtatParcAlertesModel alertes;
  final bool isWide;
  const _AlertesSection({required this.alertes, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final n = alertes;
    String s(int c) => c > 1 ? 's' : '';

    final tiles = <Widget>[
      if (n.documentsExpirantSous30Jours > 0)
        _AlerteTile(
          icon: Icons.description_outlined,
          color: const Color(0xFFE65100),
          gras: '${n.documentsExpirantSous30Jours} document'
              '${s(n.documentsExpirantSous30Jours)}',
          reste: 'expiré${s(n.documentsExpirantSous30Jours)} '
              'ou expirant sous 30 j',
        ),
      if (n.maintenancesDuesSous7Jours > 0)
        _AlerteTile(
          icon: Icons.build_outlined,
          color: const Color(0xFFE65100),
          gras: '${n.maintenancesDuesSous7Jours} maintenance'
              '${s(n.maintenancesDuesSous7Jours)}',
          reste: 'due${s(n.maintenancesDuesSous7Jours)} sous 7 j',
        ),
      if (n.permisExpires > 0)
        _AlerteTile(
          icon: Icons.badge_outlined,
          color: const Color(0xFFC62828),
          gras: '${n.permisExpires} permis',
          reste: 'chauffeur expiré${s(n.permisExpires)}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(
            'Alertes préventives (30 j)',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
        if (isWide)
          // Voir `_KpiSection` : `IntrinsicHeight` évite que `stretch`
          // hérite de la hauteur infinie du `ListView` et masque les cartes.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: tiles[i]),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                tiles[i],
              ],
            ],
          ),
      ],
    );
  }
}

class _AlerteTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String gras;
  final String reste;

  const _AlerteTile({
    required this.icon,
    required this.color,
    required this.gras,
    required this.reste,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$gras ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  TextSpan(
                    text: reste,
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Erreur ───────────────────────────────────────────────────────────────────

class _ErreurSynthese extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErreurSynthese({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 20, color: Colors.red.shade400),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Impossible de charger l'état de parc",
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
