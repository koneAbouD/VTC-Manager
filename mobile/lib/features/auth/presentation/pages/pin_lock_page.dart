import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../providers/unlock_outcome.dart';
import '../widgets/auth_ui.dart';
import 'pin_brand.dart';

/// Écran d'accès à l'application : la session est ouverte, cinq chiffres — ou
/// un doigt, quand la biométrie est activée — suffisent à la rouvrir.
///
/// La déconnexion (en haut à droite) et « Code TMK oublié ? » mènent toutes
/// deux à la page de connexion complète, en purgeant le coffre.
class PinLockPage extends ConsumerStatefulWidget {
  const PinLockPage({super.key});

  @override
  ConsumerState<PinLockPage> createState() => _PinLockPageState();
}

class _PinLockPageState extends ConsumerState<PinLockPage> {
  String _code = '';
  String? _message;
  int _errorTick = 0;
  bool _busy = false;

  /// Modalité biométrique de l'appareil, une fois l'option confirmée active.
  /// `null` tant qu'on ne sait pas, ou quand il n'y a rien à proposer.
  BiometricAvailability? _biometrie;

  /// Invite système ouverte. Distinct de [_busy] : la fenêtre de l'OS occupe
  /// déjà l'écran et bloque les touches, l'application n'a donc rien à
  /// afficher par-dessus. Ce drapeau ne sert qu'à ne pas lancer deux invites.
  bool _invitationSysteme = false;

  @override
  void initState() {
    super.initState();
    // Motif du verrouillage (inactivité…), affiché tant que rien n'est saisi.
    final state = ref.read(authNotifierProvider);
    if (state is AuthLocked) _message = state.message;
    _preparerBiometrie();
  }

  /// Prépare la touche biométrique et, si l'option est active, lance l'invite
  /// système d'emblée : c'est le geste attendu, autant l'éviter à l'utilisateur.
  Future<void> _preparerBiometrie() async {
    final notifier = ref.read(authNotifierProvider.notifier);
    if (!await notifier.isBiometricsEnabled()) return;

    final dispo = await notifier.biometricAvailability();
    if (!mounted || !dispo.disponible) return;

    setState(() => _biometrie = dispo);
    await _deverrouillerParBiometrie();
  }

  Future<void> _deverrouillerParBiometrie() async {
    if (_busy || _invitationSysteme) return;
    setState(() {
      _invitationSysteme = true;
      _message = null;
    });

    final notifier = ref.read(authNotifierProvider.notifier);
    final outcome = await notifier.unlockWithBiometrics(
      // L'OS a reconnu l'utilisateur : sa fenêtre se referme, et ce qui suit
      // (déchiffrement du coffre, réouverture de session) peut durer. C'est
      // seulement à partir d'ici que l'attente mérite d'être montrée.
      onAccepted: () {
        if (mounted) {
          setState(() {
            _invitationSysteme = false;
            _busy = true;
          });
        }
      },
    );
    if (!mounted) return;
    _invitationSysteme = false;
    _traiter(outcome);

    // L'option a pu être abandonnée en chemin (plus aucune empreinte enrôlée,
    // capteur absent) : la touche s'efface avec elle.
    if (outcome is UnlockBiometricsFailed &&
        !await notifier.isBiometricsEnabled() &&
        mounted) {
      setState(() => _biometrie = null);
    }
  }

  Future<void> _onDigit(String digit) async {
    if (_busy || _code.length >= PinService.codeLength) return;

    setState(() {
      _code += digit;
      _message = null;
    });

    if (_code.length == PinService.codeLength) await _submit();
  }

  void _onBackspace() {
    if (_busy || _code.isEmpty) return;
    setState(() => _code = _code.substring(0, _code.length - 1));
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final outcome = await ref.read(authNotifierProvider.notifier).unlock(_code);
    if (!mounted) return;
    _traiter(outcome);
  }

  void _traiter(UnlockOutcome outcome) {
    switch (outcome) {
      // Le changement d'état fait disparaître cet écran. On relâche tout de
      // même l'indicateur : si l'écran survit (transition retardée, cas
      // imprévu), l'utilisateur doit pouvoir ressaisir plutôt que rester
      // devant un écran qui tourne sans fin.
      case UnlockOk():
      case UnlockRequiresLogin():
        setState(() {
          _busy = false;
          _code = '';
        });

      case UnlockWrong(:final remainingAttempts):
        _reject(remainingAttempts == 1
            ? 'Code incorrect. Dernier essai avant déconnexion.'
            : 'Code incorrect. $remainingAttempts essais restants.');

      case UnlockWait(:final remaining):
        _reject(
          'Trop de tentatives. Réessayez dans ${remaining.inSeconds + 1} s.',
        );

      case UnlockOffline(:final message):
        _reject(message);

      // Traité en amont par [_deverrouillerParBiometrie], qui doit aussi
      // décider du sort de la touche.
      case UnlockBiometricsFailed(:final message):
        message == null
            ? setState(() => _busy = false)
            : _reject(message);
    }
  }

  void _reject(String message) {
    setState(() {
      _busy = false;
      _code = '';
      _message = message;
      _errorTick++;
    });
  }

  /// Déconnexion : retour à la page de connexion, **code conservé**. La
  /// prochaine connexion le redemandera au lieu d'en faire choisir un nouveau.
  Future<void> _confirmLogout() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => const _LogoutDialog(),
    );
    if (confirme ?? false) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  /// « Code TMK oublié ? » : le seul geste qui abandonne le code. L'utilisateur
  /// se reconnecte puis en choisit un nouveau.
  Future<void> _confirmForget() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Code TMK oublié ?'),
        content: const Text(
          'Votre code sera effacé de cet appareil. Reconnectez-vous avec votre '
          'identifiant et votre mot de passe, puis choisissez un nouveau code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Effacer le code'),
          ),
        ],
      ),
    );
    if (confirme ?? false) {
      await ref.read(authNotifierProvider.notifier).forgetPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometrie = _biometrie;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: PinLayout(
        theme: pinTheme,
        brand: const PinBrand(),
        // Sans titre à afficher, le bloc logo + cases descend vers le centre.
        topSpacing: 48,
        prompt: biometrie == null
            ? 'Veuillez saisir votre code TMK'
            : 'Utilisez ${biometrie.libelleAvecArticle} '
                'ou saisissez votre code TMK',
        length: PinService.codeLength,
        filled: _code.length,
        errorTick: _errorTick,
        message: _message,
        busy: _busy,
        onDigit: _onDigit,
        onBackspace: _onBackspace,
        // Touche en bas à gauche du pavé, là où les OS la placent.
        auxKey: biometrie == null
            ? null
            : PinAuxKey(
                icon: biometrie.icone,
                label: 'Déverrouiller avec ${biometrie.libelleAvecArticle}',
                onTap: _deverrouillerParBiometrie,
              ),
        action: IconButton(
          onPressed: _busy ? null : _confirmLogout,
          icon: const Icon(Icons.logout_rounded),
          color: AppColors.dark,
          tooltip: 'Se déconnecter',
        ),
        footer: TextButton(
          onPressed: _busy ? null : _confirmForget,
          style: TextButton.styleFrom(foregroundColor: AppColors.dark),
          child: const Text(
            'Code TMK oublié ?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// « Se déconnecter ? OUI / NON » — la session est fermée, le code conservé.
class _LogoutDialog extends StatelessWidget {
  const _LogoutDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Se déconnecter ?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: AppColors.dark),
      ),
      content: const Text(
        'Vous gardez votre code TMK : il vous sera simplement redemandé à la '
        'prochaine connexion.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: AppColors.label, height: 1.4),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        SizedBox(
          width: 120,
          child: AuthPrimaryButton(
            label: 'OUI',
            onPressed: () => Navigator.of(context).pop(true),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'NON',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
