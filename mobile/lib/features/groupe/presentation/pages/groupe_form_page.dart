import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import 'gestionnaire_form_page.dart';
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

final _gfSecureStorage =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _gfApiClient = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_gfSecureStorage)));

final _gestionnairesProvider =
    FutureProvider<List<GestionnaireLocal>>((ref) async {
  final client = ref.watch(_gfApiClient);
  final response = await client.get('/v1/utilisateurs/gestionnaires');
  final List data = response as List;
  return data
      .map((e) => GestionnaireLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _typesActivitesProvider =
    FutureProvider<List<TypeActiviteLocal>>((ref) async {
  final client = ref.watch(_gfApiClient);
  final response = await client.get('/v1/types-activites');
  final List data = response as List;
  return data
      .map((e) => TypeActiviteLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Page ──────────────────────────────────────────────────────────────────────

class GroupeFormPage extends ConsumerStatefulWidget {
  const GroupeFormPage({super.key});

  @override
  ConsumerState<GroupeFormPage> createState() => _GroupeFormPageState();
}

class _GroupeFormPageState extends ConsumerState<GroupeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TypeActiviteLocal? _typeActivite;
  GestionnaireLocal? _gestionnaire;
  bool _saving = false;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateGestionnaire() async {
    final nav = Navigator.of(context);
    final result = await nav.push<GestionnaireLocal>(
      MaterialPageRoute(builder: (_) => const GestionnaireFormPage()),
    );
    if (result != null) {
      ref.invalidate(_gestionnairesProvider);
      setState(() => _gestionnaire = result);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(_gfApiClient);
      final desc = _descCtrl.text.trim();
      final json = await client.post('/v1/groupes', {
        'nom': _nomCtrl.text.trim(),
        if (desc.isNotEmpty) 'description': desc,
        if (_typeActivite != null) 'typeActiviteId': _typeActivite!.id,
        if (_gestionnaire != null) 'gestionnaireUserId': _gestionnaire!.id,
      });
      var groupe = GroupeLocal.fromJson(json as Map<String, dynamic>);
      // Enrichir avec le gestionnaire sélectionné pour l'affichage
      if (_gestionnaire != null) {
        groupe = groupe.copyWith(gestionnaire: _gestionnaire);
      }
      if (!mounted) return;
      Navigator.pop(context, groupe);
    } catch (e) {
      if (mounted) _appToast(context, 'Erreur : $e', type: _ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gestionnairesAsync = ref.watch(_gestionnairesProvider);
    final typesAsync = ref.watch(_typesActivitesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Nouveau groupe'),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // ── Nom ──
                    const _Label(
                        icon: Icons.group_work_outlined,
                        text: 'Nom du groupe'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nomCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDeco(
                          hint: 'Ex : Groupe A, Nuit, Aéroport…'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Le nom est obligatoire'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // ── Description ──
                    const _Label(
                        icon: Icons.notes_outlined,
                        text: 'Description (facultative)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: _inputDeco(
                          hint: 'Courte description du groupe…'),
                    ),
                    const SizedBox(height: 20),

                    // ── Type d'activité ──
                    const _Label(
                        icon: Icons.category_outlined,
                        text: "Type d'activité (facultatif)"),
                    const SizedBox(height: 8),
                    typesAsync.when(
                      loading: () => _LoadingTile(),
                      error: (_, __) => _ErrorTile(
                        message:
                            "Impossible de charger les types d'activité",
                        onRetry: () =>
                            ref.invalidate(_typesActivitesProvider),
                      ),
                      data: (types) => types.isEmpty
                          ? const _EmptyTile(
                              message: "Aucun type d'activité disponible")
                          : _TypeActivitePicker(
                              types: types,
                              selected: _typeActivite,
                              onChanged: (t) =>
                                  setState(() => _typeActivite = t),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // ── Gestionnaire ──
                    Row(
                      children: [
                        const Expanded(
                          child: _Label(
                              icon: Icons.manage_accounts_outlined,
                              text: 'Gestionnaire (facultatif)'),
                        ),
                        TextButton.icon(
                          onPressed: _openCreateGestionnaire,
                          icon: const Icon(Icons.person_add_outlined,
                              size: 16),
                          label: const Text('Nouveau',
                              style: TextStyle(fontSize: 13)),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    gestionnairesAsync.when(
                      loading: () => _LoadingTile(),
                      error: (_, __) => _ErrorTile(
                        message:
                            'Impossible de charger les gestionnaires',
                        onRetry: () =>
                            ref.invalidate(_gestionnairesProvider),
                      ),
                      data: (gestionnaires) {
                        final all = [
                          if (_gestionnaire != null &&
                              gestionnaires.every(
                                  (g) => g.id != _gestionnaire!.id))
                            _gestionnaire!,
                          ...gestionnaires,
                        ];
                        if (all.isEmpty) {
                          return const _EmptyTile(
                              message:
                                  'Aucun gestionnaire — créez-en un ci-dessus');
                        }
                        return _GestionnairePicker(
                          gestionnaires: all,
                          selected: _gestionnaire,
                          onChanged: (g) =>
                              setState(() => _gestionnaire = g),
                        );
                      },
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
                      : const Text('Créer le groupe',
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
}

InputDecoration _inputDeco({required String hint}) => InputDecoration(
      hintText: hint,
      hintStyle:
          TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF5F5F5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    );

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Label({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

class _LoadingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
}

class _TypeActivitePicker extends StatelessWidget {
  final List<TypeActiviteLocal> types;
  final TypeActiviteLocal? selected;
  final ValueChanged<TypeActiviteLocal?> onChanged;

  const _TypeActivitePicker({
    required this.types,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((t) {
        final isSelected = selected?.id == t.id;
        return GestureDetector(
          onTap: () => onChanged(isSelected ? null : t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  const Icon(Icons.check,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                ],
                Text(
                  t.nom,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GestionnairePicker extends StatelessWidget {
  final List<GestionnaireLocal> gestionnaires;
  final GestionnaireLocal? selected;
  final ValueChanged<GestionnaireLocal?> onChanged;

  const _GestionnairePicker({
    required this.gestionnaires,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: gestionnaires
          .map((g) => _GestionnaireTile(
                gestionnaire: g,
                isSelected: selected?.id == g.id,
                onTap: () => onChanged(selected?.id == g.id ? null : g),
              ))
          .toList(),
    );
  }
}

class _GestionnaireTile extends StatelessWidget {
  final GestionnaireLocal gestionnaire;
  final bool isSelected;
  final VoidCallback onTap;

  const _GestionnaireTile({
    required this.gestionnaire,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(
                      color: AppColors.primary
                          .withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  child: Text(
                    gestionnaire.displayName.isNotEmpty
                        ? gestionnaire.displayName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gestionnaire.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isSelected
                              ? AppColors.primary
                              : Colors.black87,
                        ),
                      ),
                      if (gestionnaire.email != null &&
                          gestionnaire.email!.isNotEmpty)
                        Text(
                          gestionnaire.email!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: AppColors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorTile({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
              child: Text(message,
                  style: TextStyle(color: Colors.red.shade700))),
          TextButton(
              onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String message;
  const _EmptyTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message,
          style: TextStyle(color: Colors.grey.shade500),
          textAlign: TextAlign.center),
    );
  }
}