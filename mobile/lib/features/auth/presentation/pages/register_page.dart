import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_ui.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).register(
          username: _username.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          firstName:
              _firstName.text.trim().isEmpty ? null : _firstName.text.trim(),
          lastName:
              _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final loading = state is AuthLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (!mounted) return;
      if (next is AuthError) {
        authToast(context, next.message, type: AuthToastType.error);
      } else if (next is AuthUnauthenticated) {
        authToast(context, 'Compte créé ! Connectez-vous.');
        Navigator.pop(context);
      }
    });

    return AuthScaffold(
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrand(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Créer un compte',
              subtitle: 'Rejoignez VTC Manager en quelques secondes',
              compact: true,
            ),
            const SizedBox(height: 24),
            AuthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _lastName,
                    decoration: authInputDecoration(
                        label: 'Nom', icon: Icons.badge_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _firstName,
                    decoration: authInputDecoration(
                        label: 'Prénom',
                        icon: Icons.badge_outlined),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _username,
                    decoration: authInputDecoration(
                        label: "Nom d'utilisateur *",
                        icon: Icons.person_outline_rounded),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (v.length < 3) return 'Au moins 3 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: authInputDecoration(
                        label: 'Email *', icon: Icons.email_outlined),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (!v.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: authInputDecoration(
                      label: 'Mot de passe *',
                      icon: Icons.lock_outline_rounded,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: kAuthHint,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Requis';
                      if (v.length < 8) return 'Au moins 8 caractères';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirmPassword,
                    obscureText: _obscure,
                    decoration: authInputDecoration(
                        label: 'Confirmer le mot de passe *',
                        icon: Icons.lock_reset_rounded),
                    validator: (v) => v != _password.text
                        ? 'Les mots de passe ne correspondent pas'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: "S'inscrire",
                    loading: loading,
                    onPressed: loading ? null : _register,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Déjà un compte ?',
                    style: TextStyle(color: kAuthHint, fontSize: 14)),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: TextButton.styleFrom(
                    foregroundColor: kAuthPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Se connecter',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
