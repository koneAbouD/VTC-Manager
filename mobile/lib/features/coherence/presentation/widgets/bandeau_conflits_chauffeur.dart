import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/conflit_chauffeur.dart';
import '../providers/coherence_provider.dart';

/// Rappelle, sur la période affichée, les journées où un chauffeur porte des
/// créances sur plusieurs véhicules.
///
/// La génération n'a pas bloqué ces lignes : refuser d'en créer une aurait
/// laissé une recette non réclamée, ce qui coûte plus cher qu'une recette en
/// trop. Elle a notifié le jour même ; ce bandeau le rappelle tant que rien
/// n'a été tranché — annuler la ligne de trop, ou la réaffecter.
///
/// Discret par nature : replié, il tient en une ligne, et il disparaît de
/// lui-même dès qu'il n'y a plus rien à signaler.
class BandeauConflitsChauffeur extends ConsumerStatefulWidget {
  final DateTime debut;
  final DateTime fin;

  /// Appelé quand l'utilisateur touche une journée : à l'écran de s'y rendre.
  final void Function(DateTime jour) onVoirJour;

  const BandeauConflitsChauffeur({
    super.key,
    required this.debut,
    required this.fin,
    required this.onVoirJour,
  });

  @override
  ConsumerState<BandeauConflitsChauffeur> createState() =>
      _BandeauConflitsChauffeurState();
}

class _BandeauConflitsChauffeurState
    extends ConsumerState<BandeauConflitsChauffeur> {
  bool _deplie = false;

  @override
  Widget build(BuildContext context) {
    final asyncConflits = ref.watch(
        conflitsChauffeurProvider(PlageCoherence(widget.debut, widget.fin)));
    final conflits = asyncConflits.valueOrNull ?? const <ConflitChauffeur>[];

    // Rien à dire, ou pas encore de réponse : l'écran reste tel qu'il est.
    // Un bandeau qui apparaît puis s'évapore vaut moins que pas de bandeau.
    if (conflits.isEmpty) return const SizedBox.shrink();

    const teinte = AppColors.warning;
    final jourFmt = DateFormat('dd/MM');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _deplie = !_deplie),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: teinte.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: teinte.withValues(alpha: 0.28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: teinte),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _resume(conflits.length),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.dark),
                        ),
                      ),
                      Icon(
                        _deplie
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: teinte,
                      ),
                    ],
                  ),
                  if (_deplie) ...[
                    const SizedBox(height: 8),
                    for (final c in conflits)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => widget.onVoirJour(c.date),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 5),
                            child: Row(
                              children: [
                                Text(jourFmt.format(c.date),
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: teinte)),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    '${c.chauffeurNom} · '
                                    '${c.immatriculations.join(" et ")}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 11.5, color: AppColors.label),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    size: 16, color: AppColors.hint),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, top: 2),
                      child: Text(
                        'Un chauffeur ne conduit qu’un véhicule par jour. '
                        'Annulez la créance en trop, ou réaffectez-la.',
                        style: TextStyle(fontSize: 11, color: AppColors.hint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _resume(int nombre) {
    return nombre == 1
        ? '1 chauffeur sur deux véhicules le même jour'
        : '$nombre journées avec un chauffeur sur plusieurs véhicules';
  }
}
