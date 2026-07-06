import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../providers/vidanges_provider.dart';
import '../widgets/vidange_form_dialog.dart';

String _grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

String _fmtKm(int? km) => km == null ? '—' : '${_grouped(km)} km';
String _fmtDate(DateTime? d) =>
    d == null ? '—' : DateFormat('dd MMM yyyy', 'fr_FR').format(d);

/// Statut de la prochaine vidange, dérivé du km actuel et de la cible.
enum _StatutVidange { aJour, bientot, enRetard, inconnu }

extension _StatutUi on _StatutVidange {
  Color get color => switch (this) {
        _StatutVidange.aJour => AppColors.primary,
        _StatutVidange.bientot => AppColors.warning,
        _StatutVidange.enRetard => AppColors.error,
        _StatutVidange.inconnu => AppColors.hint,
      };
  String get label => switch (this) {
        _StatutVidange.aJour => 'À jour',
        _StatutVidange.bientot => 'Bientôt',
        _StatutVidange.enRetard => 'En retard',
        _StatutVidange.inconnu => 'Non planifiée',
      };
  IconData get icon => switch (this) {
        _StatutVidange.aJour => Icons.check_circle_rounded,
        _StatutVidange.bientot => Icons.access_time_rounded,
        _StatutVidange.enRetard => Icons.warning_amber_rounded,
        _StatutVidange.inconnu => Icons.help_outline_rounded,
      };
}

/// Historique des vidanges d'un véhicule (de la plus récente à la plus ancienne).
class VidangesHistoriquePage extends ConsumerWidget {
  final int vehiculeId;
  final String? vehiculeLabel;
  final int? kilometrageActuel;

  const VidangesHistoriquePage({
    super.key,
    required this.vehiculeId,
    this.vehiculeLabel,
    this.kilometrageActuel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(vidangesByVehiculeProvider(vehiculeId));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: Column(
        children: [
          _Header(
            label: vehiculeLabel,
            onAdd: () async {
              final created = await showVidangeFormDialog(
                context,
                vehiculeId: vehiculeId,
                kilometrageActuel: kilometrageActuel,
              );
              if (created == true) {
                ref.invalidate(vidangesByVehiculeProvider(vehiculeId));
              }
            },
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorView(
                onRetry: () =>
                    ref.invalidate(vidangesByVehiculeProvider(vehiculeId)),
              ),
              data: (vidanges) {
                if (vidanges.isEmpty) return const _EmptyView();
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async =>
                      ref.invalidate(vidangesByVehiculeProvider(vehiculeId)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    children: [
                      _SummaryCard(
                        derniere: vidanges.first,
                        kilometrageActuel: kilometrageActuel,
                      ),
                      const SizedBox(height: 22),
                      _TimelineHeader(count: vidanges.length),
                      const SizedBox(height: 10),
                      for (int i = 0; i < vidanges.length; i++)
                        _TimelineTile(
                          vidange: vidanges[i],
                          isFirst: i == 0,
                          isLast: i == vidanges.length - 1,
                          derniere: i == 0,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── En-tête gradient ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String? label;
  final VoidCallback onAdd;
  const _Header({this.label, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    // En-tête standard de l'app (cf. AppHeader) : fond clair, texte foncé,
    // bouton retour ovale. Un sous-titre véhicule est ajouté sous le titre.
    return Container(
      color: AppColors.header,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 56,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.headerButton,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 18, color: AppColors.dark),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Historique des vidanges',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (label != null && label!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      label!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.hint,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ],
              ),
            ),
            AppHeaderAction(icon: Icons.add_rounded, onTap: onAdd),
          ]),
        ),
      ),
    );
  }
}

// ── Carte résumé (dernière vidange + jauge vers la prochaine) ──────────────

class _SummaryCard extends StatelessWidget {
  final Vidange derniere;
  final int? kilometrageActuel;
  const _SummaryCard({required this.derniere, this.kilometrageActuel});

  _StatutVidange get _statut {
    final cible = derniere.kilometrageProchaineVidange;
    final actuel = kilometrageActuel;
    if (cible == null || actuel == null) return _StatutVidange.inconnu;
    final reste = cible - actuel;
    if (reste <= 0) return _StatutVidange.enRetard;
    if (reste <= 1000) return _StatutVidange.bientot;
    return _StatutVidange.aJour;
  }

  double? get _progress {
    final base = derniere.kilometrageVidange;
    final cible = derniere.kilometrageProchaineVidange;
    final actuel = kilometrageActuel;
    if (cible == null || actuel == null || cible <= base) return null;
    return ((actuel - base) / (cible - base)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final statut = _statut;
    final progress = _progress;
    final cible = derniere.kilometrageProchaineVidange;
    final reste = (cible != null && kilometrageActuel != null)
        ? cible - kilometrageActuel!
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF6FBF7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4EFE7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('DERNIÈRE VIDANGE',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: AppColors.label)),
              const Spacer(),
              _StatutChip(statut: statut),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _grouped(derniere.kilometrageVidange),
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: AppColors.dark,
                    letterSpacing: -1),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 4, left: 4),
                child: Text('km',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.label)),
              ),
              const Spacer(),
              Row(children: [
                const Icon(Icons.event_rounded,
                    size: 14, color: AppColors.hint),
                const SizedBox(width: 5),
                Text(_fmtDate(derniere.dateVidange),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.label)),
              ]),
            ],
          ),
          if (cible != null) ...[
            const SizedBox(height: 18),
            _ProgressBar(value: progress ?? 0, color: statut.color),
            const SizedBox(height: 10),
            Row(
              children: [
                _footLabel(
                    Icons.flag_rounded, 'Prochaine · ${_fmtKm(cible)}'),
                const Spacer(),
                if (reste != null)
                  Text(
                    reste > 0
                        ? 'Reste ${_grouped(reste)} km'
                        : 'Dépassé de ${_grouped(-reste)} km',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: statut.color),
                  ),
              ],
            ),
            if (derniere.dateProchaineVidange != null) ...[
              const SizedBox(height: 6),
              _footLabel(Icons.schedule_rounded,
                  'Prévue le ${_fmtDate(derniere.dateProchaineVidange)}'),
            ],
          ] else ...[
            const SizedBox(height: 14),
            _footLabel(Icons.info_outline_rounded,
                'Aucune prochaine vidange planifiée'),
          ],
        ],
      ),
    );
  }

  Widget _footLabel(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.hint),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(fontSize: 12.5, color: AppColors.hint)),
        ],
      );
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(children: [
        Container(height: 9, color: const Color(0xFFEDF2EE)),
        FractionallySizedBox(
          widthFactor: value == 0 ? 0.02 : value,
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.7), color],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StatutChip extends StatelessWidget {
  final _StatutVidange statut;
  const _StatutChip({required this.statut});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statut.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(statut.icon, size: 13, color: statut.color),
        const SizedBox(width: 5),
        Text(statut.label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: statut.color)),
      ]),
    );
  }
}

// ── Timeline ───────────────────────────────────────────────────────────────

class _TimelineHeader extends StatelessWidget {
  final int count;
  const _TimelineHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Text('Chronologie',
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.dark)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$count',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark)),
      ),
    ]);
  }
}

class _TimelineTile extends StatelessWidget {
  final Vidange vidange;
  final bool isFirst;
  final bool isLast;
  final bool derniere;
  const _TimelineTile({
    required this.vidange,
    required this.isFirst,
    required this.isLast,
    required this.derniere,
  });

  @override
  Widget build(BuildContext context) {
    final accent = derniere ? AppColors.primary : AppColors.hint;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Rail (ligne + pastille)
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: isFirst
                      ? Colors.transparent
                      : const Color(0xFFDBE3EC),
                ),
                Container(
                  width: derniere ? 16 : 12,
                  height: derniere ? 16 : 12,
                  decoration: BoxDecoration(
                    color: derniere ? AppColors.primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: derniere ? AppColors.primary : accent,
                        width: 2),
                    boxShadow: derniere
                        ? [
                            BoxShadow(
                              color:
                                  AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                            )
                          ]
                        : null,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : const Color(0xFFDBE3EC),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Carte
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: derniere
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : const Color(0xFFE9EDF3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(_fmtDate(vidange.dateVidange),
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppColors.dark)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_fmtKm(vidange.kilometrageVidange),
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark)),
                      ),
                    ]),
                    if (vidange.dateProchaineVidange != null ||
                        vidange.kilometrageProchaineVidange != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        const Icon(Icons.arrow_forward_rounded,
                            size: 14, color: AppColors.hint),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Prochaine : ${_fmtDate(vidange.dateProchaineVidange)} · ${_fmtKm(vidange.kilometrageProchaineVidange)}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.hint),
                          ),
                        ),
                      ]),
                    ],
                    if ((vidange.commentaire ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.fieldFill,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          vidange.commentaire!.trim(),
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.label,
                              height: 1.35),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── États vides / erreur ───────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryTint,
                AppColors.primaryTint.withValues(alpha: 0.4),
              ],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.oil_barrel_rounded,
              size: 42, color: AppColors.primary),
        ),
        const SizedBox(height: 18),
        const Text('Aucune vidange enregistrée',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.dark)),
        const SizedBox(height: 6),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Appuyez sur + en haut à droite pour consigner le premier entretien.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.hint, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.hint),
        const SizedBox(height: 14),
        const Text('Impossible de charger les vidanges',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.label)),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          label: const Text('Réessayer'),
        ),
      ]),
    );
  }
}
