import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_ui.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final error = await ref
        .read(authNotifierProvider.notifier)
        .forgotPassword(_email.text.trim());
    setState(() {
      _loading = false;
      _sent = error == null;
    });
    if (mounted) {
      authToast(
        context,
        error ?? 'Email de réinitialisation envoyé !',
        type: error != null ? AuthToastType.error : AuthToastType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: _sent ? _successView() : _formView(),
    );
  }

  Widget _formView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AuthBrand(
            icon: Icons.lock_reset_rounded,
            title: 'Mot de passe oublié',
            subtitle:
                'Saisissez votre email pour recevoir un lien de réinitialisation.',
          ),
          const SizedBox(height: 32),
          AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: authInputDecoration(
                    label: 'Email',
                    icon: Icons.email_outlined,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: 'Envoyer le lien',
                  icon: Icons.send_rounded,
                  loading: _loading,
                  onPressed: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _successView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded,
              size: 46, color: kAuthPrimary),
        ),
        const SizedBox(height: 24),
        const Text(
          'Email envoyé',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: kAuthDark),
        ),
        const SizedBox(height: 8),
        Text(
          'Un lien de réinitialisation a été envoyé à\n${_email.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: kAuthHint, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: AuthPrimaryButton(
            label: 'Retour à la connexion',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}
