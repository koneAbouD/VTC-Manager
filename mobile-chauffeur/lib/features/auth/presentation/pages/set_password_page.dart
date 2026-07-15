import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../providers/auth_controller.dart';

/// Permet au chauffeur connecté de définir/changer son mot de passe,
/// activant ainsi la connexion par mot de passe.
class SetPasswordPage extends ConsumerStatefulWidget {
  const SetPasswordPage({super.key});

  @override
  ConsumerState<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends ConsumerState<SetPasswordPage> {
  final _mdp = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  bool _visible = false;

  @override
  void dispose() {
    _mdp.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _enregistrer() async {
    final mdp = _mdp.text;
    if (mdp.length < 6) {
      _snack('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (mdp != _confirmation.text) {
      _snack('Les deux mots de passe ne correspondent pas.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).setPassword(mdp);
      if (!mounted) return;
      _snack('Mot de passe enregistré.');
      Navigator.of(context).pop();
    } catch (e) {
      _snack(messageFromError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Définissez un mot de passe pour vous connecter sans code WhatsApp.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _mdp,
              obscureText: !_visible,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmation,
              obscureText: !_visible,
              onSubmitted: (_) => _enregistrer(),
              decoration: const InputDecoration(
                labelText: 'Confirmer le mot de passe',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _enregistrer,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
