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
  final _passwordFocus = FocusNode();
  bool _obscure = true;

  /// Ce qui est affiché sous le formulaire : refus du serveur, panne réseau, ou
  /// motif d'un retour forcé à la connexion.
  ({String texte, AuthToastType type, IconData? icone})? _message;

  /// Incrémenté à chaque nouveau refus, pour que deux échecs identiques se
  /// voient (secousse + retour tactile) au lieu de laisser le bandeau immobile.
  int _errorTick = 0;

  @override
  void initState() {
    super.initState();
    // Motif du retour à la connexion (session expirée, code abandonné…). Il est
    // porté par l'état, comme celui du verrouillage l'est par [AuthLocked] :
    // sans cela, l'utilisateur se retrouve devant la page de connexion sans
    // savoir pourquoi.
    final state = ref.read(authNotifierProvider);
    if (state is AuthUnauthenticated && (state.message?.isNotEmpty ?? false)) {
      _message = (
        texte: state.message!,
        type: AuthToastType.info,
        icone: Icons.info_outline_rounded,
      );
    }
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _afficher(
    String texte, {
    AuthToastType type = AuthToastType.error,
    IconData? icone,
  }) {
    setState(() {
      _message = (texte: texte, type: type, icone: icone);
      _errorTick++;
    });
  }

  /// Toute nouvelle frappe efface le message : il porte sur la tentative
  /// précédente.
  void _effacerMessage() {
    if (_message != null) setState(() => _message = null);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    _effacerMessage();
    await ref
        .read(authNotifierProvider.notifier)
        .login(_username.text.trim(), _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final loading = state is AuthLoading;

    ref.listen(authNotifierProvider, (_, next) {
      if (!mounted) return;
      switch (next) {
        case AuthError(:final message, :final indisponible):
          _afficher(
            message,
            type: indisponible ? AuthToastType.warning : AuthToastType.error,
            icone: indisponible ? Icons.cloud_off_rounded : null,
          );
          // Le serveur n'a pas tranché : la saisie n'est pas en cause, on la
          // conserve pour que le prochain essai tienne en un geste — de la même
          // façon qu'un déverrouillage hors ligne ne coûte aucun essai. Sinon
          // seul le mot de passe est effacé : faire retaper l'identifiant après
          // une faute de frappe n'apporte rien.
          if (!indisponible) {
            _password.clear();
            _passwordFocus.requestFocus();
          }

        case AuthUnauthenticated(:final message?):
          _afficher(
            message,
            type: AuthToastType.info,
            icone: Icons.info_outline_rounded,
          );

        default:
          break;
      }
    });

    final message = _message;

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
                  AuthMessage(
                    message: message?.texte,
                    type: message?.type ?? AuthToastType.error,
                    icon: message?.icone,
                    tick: _errorTick,
                  ),
                  TextFormField(
                    controller: _username,
                    decoration: authInputDecoration(
                      label: "Nom d'utilisateur",
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Requis' : null,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => _effacerMessage(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    focusNode: _passwordFocus,
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
                    onChanged: (_) => _effacerMessage(),
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
