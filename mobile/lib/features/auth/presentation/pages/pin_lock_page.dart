import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../providers/unlock_outcome.dart';
import '../widgets/auth_ui.dart';
import 'pin_brand.dart';

/// Écran d'accès à l'application : la session est ouverte, cinq chiffres
/// suffisent à la rouvrir.
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

  @override
  void initState() {
    super.initState();
    // Motif du verrouillage (inactivité…), affiché tant que rien n'est saisi.
    final state = ref.read(authNotifierProvider);
    if (state is AuthLocked) _message = state.message;
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

  Future<void> _confirmLogout() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => const _LogoutDialog(),
    );
    if (confirme ?? false) {
      await ref.read(authNotifierProvider.notifier).forgetPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: PinLayout(
        theme: pinTheme,
        brand: const PinBrand(),
        prompt: 'Veuillez saisir votre code TMK',
        length: PinService.codeLength,
        filled: _code.length,
        errorTick: _errorTick,
        message: _message,
        busy: _busy,
        onDigit: _onDigit,
        onBackspace: _onBackspace,
        action: IconButton(
          onPressed: _busy ? null : _confirmLogout,
          icon: const Icon(Icons.logout_rounded),
          color: AppColors.dark,
          tooltip: 'Se déconnecter',
        ),
        footer: TextButton(
          onPressed: _busy ? null : _confirmLogout,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text(
            'Code TMK oublié ?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// « Se déconnecter ? OUI / NON » — le code et la session sont abandonnés.
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
