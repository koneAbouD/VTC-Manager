import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../providers/auth_controller.dart';
import 'otp_verify_page.dart';

enum _Mode { otp, motDePasse }

/// Écran de connexion : bascule entre OTP (WhatsApp) et mot de passe.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  _Mode _mode = _Mode.otp;

  final _telOtp = TextEditingController();
  final _identifiant = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _loading = false;
  bool _motDePasseVisible = false;

  @override
  void dispose() {
    _telOtp.dispose();
    _identifiant.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _envoyerOtp() async {
    final tel = _telOtp.text.trim();
    if (tel.length < 8) {
      _snack('Entrez un numéro de téléphone valide.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(tel);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpVerifyPage(telephone: tel),
      ));
    } catch (e) {
      _snack(messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _motDePasseOublie() async {
    final tel = _identifiant.text.trim();
    if (tel.length < 8 || !RegExp(r'^[0-9+ ]+$').hasMatch(tel)) {
      _snack('Saisissez votre numéro de téléphone dans le champ identifiant, '
          'puis touchez « Mot de passe oublié ».');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).requestOtp(tel);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpVerifyPage(telephone: tel, isReset: true),
      ));
    } catch (e) {
      _snack(messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _connexionMotDePasse() async {
    final id = _identifiant.text.trim();
    final mdp = _motDePasse.text;
    if (id.isEmpty || mdp.isEmpty) {
      _snack('Renseignez votre identifiant et votre mot de passe.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).passwordLogin(id, mdp);
      // Le routeur racine bascule automatiquement vers le tableau de bord.
    } catch (e) {
      _snack(messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo_tmk.png',
                    height: 96,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                        Icons.local_taxi_rounded,
                        size: 72,
                        color: theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Espace Chauffeur',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 28),
              SegmentedButton<_Mode>(
                segments: const [
                  ButtonSegment(
                      value: _Mode.otp,
                      icon: Icon(Icons.chat_rounded),
                      label: Text('Téléphone')),
                  ButtonSegment(
                      value: _Mode.motDePasse,
                      icon: Icon(Icons.password_rounded),
                      label: Text('Mot de passe')),
                ],
                selected: {_mode},
                onSelectionChanged: _loading
                    ? null
                    : (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 28),
              if (_mode == _Mode.otp) _formOtp(theme) else _formMotDePasse(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formOtp(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Recevez un code de connexion par WhatsApp.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
          controller: _telOtp,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: 'Ex. 0707070707',
            prefixIcon: Icon(Icons.phone_rounded),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loading ? null : _envoyerOtp,
          icon: _loading ? _spinner() : const Icon(Icons.chat_rounded),
          label: Text(_loading ? 'Envoi…' : 'Recevoir le code'),
        ),
      ],
    );
  }

  Widget _formMotDePasse(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Connectez-vous avec votre identifiant et mot de passe.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54)),
        const SizedBox(height: 20),
        TextField(
          controller: _identifiant,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Identifiant (numéro de téléphone)',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _motDePasse,
          obscureText: !_motDePasseVisible,
          onSubmitted: (_) => _connexionMotDePasse(),
          decoration: InputDecoration(
            labelText: 'Mot de passe',
            prefixIcon: const Icon(Icons.lock_rounded),
            suffixIcon: IconButton(
              icon: Icon(_motDePasseVisible
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded),
              onPressed: () =>
                  setState(() => _motDePasseVisible = !_motDePasseVisible),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _loading ? null : _connexionMotDePasse,
          child: _loading ? _spinner() : const Text('Se connecter'),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _loading ? null : _motDePasseOublie,
            child: const Text('Mot de passe oublié ?'),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Astuce : connectez-vous une première fois par téléphone, '
          'puis définissez un mot de passe depuis votre espace.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
        ),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
