import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/auth_controller.dart';
import '../providers/unlock_outcome.dart';
import 'pin_brand.dart';

/// Reprise du code existant après une reconnexion.
///
/// Le chauffeur s'est déconnecté volontairement puis reconnecté : son code TMK
/// est toujours sur l'appareil. Plutôt que de lui en faire choisir un nouveau,
/// on le lui redemande — la saisie rouvre le coffre pour y ranger le refresh
/// token tout neuf.
///
/// « Code TMK oublié ? » mène ici au choix d'un nouveau code, et non à la page
/// de connexion : la session vient d'être ouverte.
class PinResumePage extends ConsumerStatefulWidget {
  final String? displayName;

  const PinResumePage({super.key, this.displayName});

  @override
  ConsumerState<PinResumePage> createState() => _PinResumePageState();
}

class _PinResumePageState extends ConsumerState<PinResumePage> {
  String _code = '';
  String? _message;
  int _errorTick = 0;
  bool _busy = false;

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
    final outcome =
        await ref.read(authControllerProvider.notifier).resumePin(_code);
    if (!mounted) return;

    switch (outcome) {
      // Le changement d'état fait disparaître cet écran ; on relâche tout de
      // même l'indicateur pour ne jamais laisser un écran qui tourne sans fin.
      case UnlockOk():
      case UnlockRequiresLogin():
      case UnlockOffline():
        setState(() {
          _busy = false;
          _code = '';
        });

      case UnlockWrong(:final remainingAttempts):
        _reject(remainingAttempts == 1
            ? 'Code incorrect. Dernier essai avant réinitialisation.'
            : 'Code incorrect. $remainingAttempts essais restants.');

      case UnlockWait(:final remaining):
        _reject(
          'Trop de tentatives. Réessayez dans ${remaining.inSeconds + 1} s.',
        );
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

  Future<void> _confirmForget() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code TMK oublié ?'),
        content: const Text(
          'Vous allez choisir un nouveau code TMK. Votre session reste '
          'ouverte : pas besoin d\'un nouveau code par WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Choisir un nouveau code'),
          ),
        ],
      ),
    );
    if (confirme ?? false) {
      await ref.read(authControllerProvider.notifier).restartPinSetup();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nom = widget.displayName;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: PinLayout(
        theme: pinTheme,
        brand: const PinBrand(),
        title: nom == null ? 'Bon retour' : 'Bon retour $nom',
        prompt: 'Saisissez votre code TMK habituel',
        length: PinService.codeLength,
        filled: _code.length,
        errorTick: _errorTick,
        message: _message,
        busy: _busy,
        onDigit: _onDigit,
        onBackspace: _onBackspace,
        // Issue de secours : s'être connecté avec le mauvais compte ne doit pas
        // enfermer dans cet écran.
        action: IconButton(
          onPressed: _busy
              ? null
              : () => ref.read(authControllerProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded),
          color: AppColors.dark,
          tooltip: 'Se déconnecter',
        ),
        footer: TextButton(
          onPressed: _busy ? null : _confirmForget,
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
