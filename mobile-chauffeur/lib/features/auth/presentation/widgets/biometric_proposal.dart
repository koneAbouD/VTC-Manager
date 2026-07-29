import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_controller.dart';

/// Propose une fois le déverrouillage biométrique, à l'entrée dans
/// l'application.
///
/// L'invite ne peut pas vivre sur l'écran de verrouillage : celui-ci disparaît
/// à l'instant même où le code est accepté. Elle s'accroche donc à l'écran qui
/// lui succède — d'où ce widget, qui se contente d'envelopper l'accueil.
///
/// Une seule proposition dans la vie de l'installation, refus compris :
/// l'option reste ensuite dans les réglages du code d'accès.
class BiometricProposal extends ConsumerStatefulWidget {
  final Widget child;

  const BiometricProposal({super.key, required this.child});

  @override
  ConsumerState<BiometricProposal> createState() => _BiometricProposalState();
}

class _BiometricProposalState extends ConsumerState<BiometricProposal> {
  @override
  void initState() {
    super.initState();
    // Après le premier rendu : l'accueil est à l'écran, la boîte se pose
    // dessus au lieu de retarder l'affichage.
    WidgetsBinding.instance.addPostFrameCallback((_) => _proposer());
  }

  Future<void> _proposer() async {
    final notifier = ref.read(authControllerProvider.notifier);
    final dispo = await notifier.biometricsToPropose();
    if (!mounted || dispo == null) return;

    // Posée avant la réponse : un refus ne doit pas revenir au prochain
    // démarrage, et une interruption non plus.
    await notifier.markBiometricsProposed();
    if (!mounted) return;

    final accepte = await showDialog<bool>(
      context: context,
      builder: (context) => _ProposalDialog(availability: dispo),
    );
    if (!mounted || !(accepte ?? false)) return;

    final erreur = await notifier.enableBiometrics();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erreur ??
              '${_capitaliser(dispo.libelle)} activé pour déverrouiller '
                  'l\'application.',
        ),
        backgroundColor: erreur == null ? AppColors.primary : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _capitaliser(String texte) =>
    texte.isEmpty ? texte : texte[0].toUpperCase() + texte.substring(1);

class _ProposalDialog extends StatelessWidget {
  final BiometricAvailability availability;

  const _ProposalDialog({required this.availability});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: Icon(availability.icone, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(
            'Utiliser ${availability.libelleAvecArticle} ?',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: AppColors.dark),
          ),
        ],
      ),
      content: const Text(
        'Vous ouvrirez l\'application d\'un geste, sans saisir vos cinq '
        'chiffres. Votre code TMK reste actif et vous sera redemandé si la '
        'reconnaissance échoue.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.label, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: 120,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'ACTIVER',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text(
              'PLUS TARD',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
