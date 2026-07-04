import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';
import '../widgets/auth_ui.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authNotifierProvider.notifier)
        .login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final loading = state is AuthLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (next is AuthError && mounted) {
        authToast(context, next.message, type: AuthToastType.error);
        // Réinitialiser les champs après chaque échec d'authentification.
        _username.clear();
        _password.clear();
      }
    });

    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AuthBrand(
              assetLogo: 'assets/images/logo_tmk.png',
              subtitle: 'Gérez votre flotte en toute simplicité',
            ),
            const SizedBox(height: 32),
            AuthCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _username,
                    decoration: authInputDecoration(
                      label: "Nom d'utilisateur",
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requis' : null,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: authInputDecoration(
                      label: 'Mot de passe',
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
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requis' : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _login(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage()),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: kAuthPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Mot de passe oublié ?',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: 'Se connecter',
                    loading: loading,
                    onPressed: loading ? null : _login,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Pas encore de compte ?',
                    style: TextStyle(color: kAuthHint, fontSize: 14)),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: kAuthPrimary,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text("S'inscrire",
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
