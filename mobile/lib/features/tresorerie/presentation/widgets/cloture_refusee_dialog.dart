import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Alerte de clôture refusée.
///
/// Elle tient de l'accusé de réception plus que de l'erreur : le mois concerné,
/// tout ce qui s'y oppose, et la marche à suivre. Le bouton d'action mène à
/// l'écran qui lève l'obstacle, plutôt que de laisser l'utilisateur le chercher.
class ClotureRefuseeDialog extends StatefulWidget {
  final String mois;
  final String message;
  final List<String> obstacles;
  final String? consigne;
  final String? actionLabel;

  const ClotureRefuseeDialog({
    super.key,
    required this.mois,
    required this.message,
    required this.obstacles,
    required this.consigne,
    required this.actionLabel,
  });

  @override
  State<ClotureRefuseeDialog> createState() => _ClotureRefuseeDialogState();
}

class _ClotureRefuseeDialogState extends State<ClotureRefuseeDialog> {
  /// La liste se coupe net quand elle déborde : sans barre, le dernier
  /// obstacle passe pour un texte tronqué plutôt que pour la suite d'une liste.
  final _defilement = ScrollController();

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mois = widget.mois;
    final message = widget.message;
    final obstacles = widget.obstacles;
    final consigne = widget.consigne;
    final actionLabel = widget.actionLabel;
    const accent = AppColors.warning;
    // Plusieurs comptes non comptés font une liste : le message résume, la
    // liste détaille. Un seul obstacle se suffit à lui-même — le répéter sous
    // forme de puce ferait doublon.
    final aListe = obstacles.length > 1;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        // La liste peut être longue : elle défile dans la boîte plutôt que de
        // la faire déborder de l'écran.
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.72),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_clock_rounded,
                      size: 28, color: accent),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Clôture impossible',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                    letterSpacing: -0.4),
              ),
              const SizedBox(height: 6),
              Text(
                '$mois reste ouvert.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.4, color: AppColors.label),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Scrollbar(
                  controller: _defilement,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _defilement,
                    // La barre longe le bord du contenu : sans cette réserve,
                    // elle passerait par-dessus le texte.
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 13, vertical: 12),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: accent.withValues(alpha: 0.22)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message,
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.dark),
                              ),
                              if (aListe)
                                for (final obstacle in obstacles) ...[
                                  const SizedBox(height: 9),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(top: 5),
                                        child: Icon(Icons.circle,
                                            size: 5, color: accent),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          obstacle,
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              height: 1.4,
                                              color: AppColors.label),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Hors de la zone défilante : la marche à suivre reste sous les
              // yeux, même quand la liste des obstacles est longue.
              if (consigne != null) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.checklist_rounded,
                        size: 17, color: AppColors.hint),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        consigne,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: AppColors.label),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.label,
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Fermer',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  if (actionLabel != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(actionLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
