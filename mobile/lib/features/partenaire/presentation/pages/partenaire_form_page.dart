import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../domain/entities/partenaire.dart';
import '../../domain/entities/type_partenaire.dart';
import '../providers/partenaire_providers.dart';

/// Création ou modification d'un partenaire.
///
/// Renvoie le partenaire enregistré à l'écran appelant, ce qui permet de le
/// présélectionner quand on le crée depuis une saisie de facture.
class PartenaireFormPage extends ConsumerStatefulWidget {
  final Partenaire? initial;
  const PartenaireFormPage({super.key, this.initial});

  @override
  ConsumerState<PartenaireFormPage> createState() => _PartenaireFormPageState();
}

class _PartenaireFormPageState extends ConsumerState<PartenaireFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _nomCtrl = TextEditingController(text: widget.initial?.nom);
  late final _telCtrl = TextEditingController(text: widget.initial?.telephone);
  late final _emailCtrl = TextEditingController(text: widget.initial?.email);
  late final _adresseCtrl =
      TextEditingController(text: widget.initial?.adresse);
  late final _ccCtrl =
      TextEditingController(text: widget.initial?.numeroCompteContribuable);

  /// Type choisi. Null tant que le référentiel n'a pas répondu, ou tant que
  /// rien n'a été sélectionné sur une création.
  late int? _typeId = widget.initial?.typeId;

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
    if (_typeId == null) {
      setState(() => _erreur = 'Choisissez un type de partenaire.');
      return;
    }
    setState(() {
      _busy = true;
      _erreur = null;
    });
    final f = Partenaire(
      nom: _nomCtrl.text.trim(),
      typeId: _typeId!,
      telephone: _telCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      adresse: _adresseCtrl.text.trim(),
      numeroCompteContribuable: _ccCtrl.text.trim(),
    );
    try {
      final ds = ref.read(partenaireDatasourceProvider);
      final enregistre = widget.initial?.id != null
          ? await ds.modifierPartenaire(widget.initial!.id!, f)
          : await ds.creerPartenaire(f);
      if (!mounted) return;
      ref.invalidate(partenairesProvider);
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
        title: widget.initial == null ? 'Nouveau partenaire' : 'Modifier',
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
            _champType(),
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

  /// Liste des types servie par les données de référence : elle suit le
  /// paramétrage, sans version d'application à livrer.
  Widget _champType() {
    final types = ref.watch(typesPartenaireProvider);
    return types.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('Types indisponibles : $e',
          style: const TextStyle(fontSize: 12, color: AppColors.error)),
      data: (liste) {
        // Le type d'un partenaire existant peut avoir été désactivé depuis :
        // on l'ajoute aux options pour ne pas le perdre à la modification.
        final options = [...liste];
        if (_typeId != null && !options.any((t) => t.id == _typeId)) {
          options.add(TypePartenaire(
              id: _typeId!, nom: widget.initial?.typeNom ?? 'Type actuel'));
        }
        return PremiumSelectField<int>(
          value: _typeId,
          hint: 'Type',
          sheetTitle: 'Type de partenaire',
          isRequired: true,
          options: options
              .map((t) => SelectOption(value: t.id, label: t.nom))
              .toList(),
          onChanged: (v) => setState(() => _typeId = v),
        );
      },
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
