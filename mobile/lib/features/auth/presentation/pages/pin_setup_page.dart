import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../providers/auth_provider.dart';
import 'pin_brand.dart';

enum _Step { current, create, confirm }

/// Création, activation ou changement du code d'accès.
///
/// Trois usages, une seule page :
///  • après la connexion — [onDone] absent : le code est obligatoire, il n'y a
///    pas de « Plus tard » ; l'application s'ouvre une fois le code installé, et
///    la seule autre issue est la déconnexion ;
///  • activation depuis les réglages — [onDone] ferme la page ;
///  • changement — [requireCurrentCode] ajoute la saisie du code actuel.
class PinSetupPage extends ConsumerStatefulWidget {
  /// Prénom à saluer (facultatif).
  final String? displayName;

  /// Appelé une fois le code installé. Si `null`, l'état d'authentification
  /// bascule seul vers l'application.
  final VoidCallback? onDone;

  /// Exige le code actuel avant d'en choisir un nouveau.
  final bool requireCurrentCode;

  const PinSetupPage({
    super.key,
    this.displayName,
    this.onDone,
    this.requireCurrentCode = false,
  });

  @override
  ConsumerState<PinSetupPage> createState() => _PinSetupPageState();
}

class _PinSetupPageState extends ConsumerState<PinSetupPage> {
  late _Step _step = widget.requireCurrentCode ? _Step.current : _Step.create;

  String _code = '';
  String? _currentCode;
  String? _newCode;
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
    switch (_step) {
      case _Step.current:
        // Vérifié à la toute fin, avec le nouveau code : une seule dérivation.
        setState(() {
          _currentCode = _code;
          _code = '';
          _step = _Step.create;
        });

      case _Step.create:
        final invalide = PinService.validate(_code);
        if (invalide != null) {
          _reject(invalide);
          return;
        }
        setState(() {
          _newCode = _code;
          _code = '';
          _step = _Step.confirm;
        });

      case _Step.confirm:
        if (_code != _newCode) {
          setState(() => _step = _Step.create);
          _reject('Les deux codes ne correspondent pas. Recommencez.');
          return;
        }
        await _install();
    }
  }

  Future<void> _install() async {
    setState(() => _busy = true);
    final notifier = ref.read(authNotifierProvider.notifier);

    final erreur = widget.requireCurrentCode
        ? await notifier.changePin(
            currentCode: _currentCode!,
            newCode: _code,
          )
        : await notifier.configurePin(
            _code,
            entrerDansLApplication: widget.onDone == null,
          );

    if (!mounted) return;
    if (erreur != null) {
      setState(() {
        _step = widget.requireCurrentCode ? _Step.current : _Step.create;
        _currentCode = null;
      });
      _reject(erreur);
      return;
    }
    widget.onDone?.call();

    // Succès sans [onDone] : c'est le changement d'état d'authentification qui
    // fait entrer dans l'application. Si cet écran est encore là, on relâche
    // l'indicateur — mieux vaut un écran utilisable qu'un chargement perpétuel.
    if (mounted) setState(() => _busy = false);
  }

  void _reject(String message) {
    setState(() {
      _busy = false;
      _code = '';
      _message = message;
      _errorTick++;
    });
  }

  /// Seule échappatoire de l'écran obligatoire : retourner à la connexion.
  Future<void> _confirmLogout() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Le code TMK est nécessaire pour utiliser l\'application. Sans lui, '
          'vous devrez vous reconnecter avec votre identifiant et votre mot de '
          'passe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (confirme ?? false) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  String get _title => switch (_step) {
        _Step.current => 'Code TMK actuel',
        _Step.create => widget.requireCurrentCode
            ? 'Nouveau code TMK'
            : (widget.displayName == null
                ? 'Bienvenue'
                : 'Bienvenue ${widget.displayName}'),
        _Step.confirm => 'Confirmez votre code',
      };

  String get _prompt => switch (_step) {
        _Step.current => 'Saisissez votre code actuel',
        _Step.create => widget.requireCurrentCode
            ? 'Choisissez vos ${PinService.codeLength} nouveaux chiffres'
            : 'Choisissez un code TMK à ${PinService.codeLength} chiffres\n'
                'pour accéder plus vite à l\'application',
        _Step.confirm => 'Saisissez à nouveau les ${PinService.codeLength} '
            'chiffres',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: PinLayout(
        theme: pinTheme,
        brand: const PinBrand(),
        title: _title,
        prompt: _prompt,
        length: PinService.codeLength,
        filled: _code.length,
        errorTick: _errorTick,
        message: _message,
        busy: _busy,
        onDigit: _onDigit,
        onBackspace: _onBackspace,
        // Depuis les réglages, on repart en arrière avec le même bouton que
        // les en-têtes du reste de l'application.
        leading: widget.onDone != null
            ? AppHeaderAction(
                icon: Icons.arrow_back_rounded,
                iconSize: 18,
                onTap: _busy ? null : () => Navigator.of(context).pop(),
              )
            : null,
        // À la suite d'une connexion, le code est obligatoire : pas de retour,
        // la seule sortie est de repartir sur la page de connexion.
        action: widget.onDone == null
            ? IconButton(
                onPressed: _busy ? null : _confirmLogout,
                icon: const Icon(Icons.logout_rounded),
                color: AppColors.dark,
                tooltip: 'Se déconnecter',
              )
            : null,
      ),
    );
  }
}
