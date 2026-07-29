import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../domain/entities/fournisseur.dart';
import '../providers/fournisseur_providers.dart';

/// Création ou modification d'un fournisseur.
///
/// Renvoie le fournisseur enregistré à l'écran appelant, ce qui permet de le
/// présélectionner quand on le crée depuis une saisie de facture.
class FournisseurFormPage extends ConsumerStatefulWidget {
  final Fournisseur? initial;
  const FournisseurFormPage({super.key, this.initial});

  @override
  ConsumerState<FournisseurFormPage> createState() => _FournisseurFormPageState();
}

class _FournisseurFormPageState extends ConsumerState<FournisseurFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nomCtrl = TextEditingController(text: widget.initial?.nom);
  late final _telCtrl = TextEditingController(text: widget.initial?.telephone);
  late final _emailCtrl = TextEditingController(text: widget.initial?.email);
  late final _adresseCtrl = TextEditingController(text: widget.initial?.adresse);
  late final _ccCtrl =
      TextEditingController(text: widget.initial?.numeroCompteContribuable);
  late TypeFournisseur _type = widget.initial?.type ?? TypeFournisseur.garage;

  bool _busy = false;
  String? _erreur;

  @override
  void dispose() {
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    _adresseCtrl.dispose();
    _ccCtrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    final f = Fournisseur(
      nom: _nomCtrl.text.trim(),
      type: _type,
      telephone: _telCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      adresse: _adresseCtrl.text.trim(),
      numeroCompteContribuable: _ccCtrl.text.trim(),
    );
    try {
      final ds = ref.read(fournisseurDatasourceProvider);
      final enregistre = widget.initial?.id != null
          ? await ds.modifierFournisseur(widget.initial!.id!, f)
          : await ds.creerFournisseur(f);
      if (!mounted) return;
      ref.invalidate(fournisseursProvider);
      Navigator.pop(context, enregistre);
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: widget.initial == null ? 'Nouveau fournisseur' : 'Modifier',
        action: AppHeaderAction(
          label: 'Enregistrer',
          loading: _busy,
          onTap: _enregistrer,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextFormField(
              controller: _nomCtrl,
              decoration: _deco('Nom'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 12),
            PremiumSelectField<TypeFournisseur>(
              value: _type,
              hint: 'Type',
              sheetTitle: 'Type de fournisseur',
              isRequired: true,
              options: TypeFournisseur.values
                  .map((t) => SelectOption(value: t, label: t.label))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _type = v ?? TypeFournisseur.autre),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telCtrl,
              keyboardType: TextInputType.phone,
              decoration: _deco('Téléphone'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: _deco('E-mail'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adresseCtrl,
              decoration: _deco('Adresse'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ccCtrl,
              decoration: _deco('N° compte contribuable',
                  aide: 'Demandé par le cabinet pour justifier la charge'),
            ),
            if (_erreur != null) ...[
              const SizedBox(height: 12),
              Text(_erreur!,
                  style: const TextStyle(fontSize: 12, color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, {String? aide}) => InputDecoration(
        labelText: label,
        helperText: aide,
        helperMaxLines: 2,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
}
