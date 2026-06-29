import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import 'groupe_models.dart';

// ── Toast helpers ──────────────────────────────────────────────────────────────
enum _ToastType { success, error, warning, info }

void _appToast(BuildContext context, String message,
    {_ToastType type = _ToastType.success, Duration? duration}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
    _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ?? (type == _ToastType.error || type == _ToastType.warning
          ? const Duration(seconds: 4) : const Duration(seconds: 2)),
    ));
}

// ── Providers locaux ──────────────────────────────────────────────────────────

final _gstSecureStorage =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _gstApiClient = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_gstSecureStorage)));

// ── Page ──────────────────────────────────────────────────────────────────────

class GestionnaireFormPage extends ConsumerStatefulWidget {
  const GestionnaireFormPage({super.key});

  @override
  ConsumerState<GestionnaireFormPage> createState() =>
      _GestionnaireFormPageState();
}

class _GestionnaireFormPageState
    extends ConsumerState<GestionnaireFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  /// Auto-remplit le username à partir du prénom + nom si non modifié manuellement.
  bool _usernameManuallyEdited = false;
  void _onNameChanged() {
    if (_usernameManuallyEdited) return;
    final first =
        _firstNameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    final last =
        _lastNameCtrl.text.trim().toLowerCase().replaceAll(' ', '');
    if (first.isNotEmpty || last.isNotEmpty) {
      _usernameCtrl.text =
          [first, last].where((s) => s.isNotEmpty).join('.');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(_gstApiClient);
      final email = _emailCtrl.text.trim();
      final json = await client.post('/v1/utilisateurs/gestionnaires', {
        'firstName': _firstNameCtrl.text.trim(),
        'lastName': _lastNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (email.isNotEmpty) 'email': email,
        'username': _usernameCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(
        context,
        GestionnaireLocal.fromJson(json as Map<String, dynamic>),
      );
    } catch (e) {
      if (mounted) _appToast(context, 'Erreur : $e', type: _ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Nouveau gestionnaire'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Nouveau gestionnaire',
                style:
                    TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Un utilisateur avec le rôle Gestionnaire sera automatiquement créé.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Prénom / Nom côte à côte
                    Row(
                      children: [
                        Expanded(
                          child: _Field(
                            controller: _firstNameCtrl,
                            label: 'Prénom',
                            hint: 'Jean',
                            icon: Icons.person_outline,
                            textCapitalization:
                                TextCapitalization.words,
                            onChanged: (_) => _onNameChanged(),
                            validator: _requiredValidator,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _Field(
                            controller: _lastNameCtrl,
                            label: 'Nom',
                            hint: 'Dupont',
                            icon: Icons.person_outline,
                            textCapitalization:
                                TextCapitalization.words,
                            onChanged: (_) => _onNameChanged(),
                            validator: _requiredValidator,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Téléphone (obligatoire)
                    _Field(
                      controller: _phoneCtrl,
                      label: 'Téléphone',
                      hint: '+221 77 000 00 00',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Téléphone obligatoire';
                        }
                        if (v.trim().length < 6) {
                          return 'Numéro invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Email (facultatif)
                    _Field(
                      controller: _emailCtrl,
                      label: 'Email (facultatif)',
                      hint: 'jean.dupont@exemple.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (!v.contains('@')) return 'Email invalide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Nom d'utilisateur
                    _Field(
                      controller: _usernameCtrl,
                      label: "Nom d'utilisateur",
                      hint: 'jean.dupont',
                      icon: Icons.alternate_email,
                      onChanged: (_) =>
                          _usernameManuallyEdited = true,
                      validator: _requiredValidator,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Créer le gestionnaire',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _requiredValidator(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(icon: icon, text: label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 15),
          ),
        ),
      ],
    );
  }
}