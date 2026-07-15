import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../providers/auth_controller.dart';
import 'set_password_page.dart';

/// Écran de saisie du code reçu par WhatsApp.
class OtpVerifyPage extends ConsumerStatefulWidget {
  final String telephone;

  /// En mode réinitialisation, après vérification on redirige vers la
  /// définition d'un nouveau mot de passe (flux « mot de passe oublié »).
  final bool isReset;

  const OtpVerifyPage({
    super.key,
    required this.telephone,
    this.isReset = false,
  });

  @override
  ConsumerState<OtpVerifyPage> createState() => _OtpVerifyPageState();
}

class _OtpVerifyPageState extends ConsumerState<OtpVerifyPage> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _renvoi = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verifier() async {
    final code = _controller.text.trim();
    if (code.length < 4) {
      _snack('Entrez le code reçu.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(widget.telephone, code);
      // Le routeur racine bascule automatiquement vers le tableau de bord.
      // En mode réinitialisation, on enchaîne sur la définition du mot de passe.
      if (widget.isReset && mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SetPasswordPage()),
          (route) => route.isFirst,
        );
      }
    } catch (e) {
      _snack(messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _renvoyer() async {
    setState(() => _renvoi = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestOtp(widget.telephone);
      _snack('Un nouveau code a été envoyé.');
    } catch (e) {
      _snack(messageFromError(e));
    } finally {
      if (mounted) setState(() => _renvoi = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.isReset ? 'Réinitialisation' : 'Vérification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text('Entrez le code',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Code envoyé par WhatsApp au ${widget.telephone}',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                    fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: '', hintText: '••••••'),
                onSubmitted: (_) => _verifier(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _verifier,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Se connecter'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _renvoi ? null : _renvoyer,
                child: Text(_renvoi ? 'Envoi…' : 'Renvoyer le code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
