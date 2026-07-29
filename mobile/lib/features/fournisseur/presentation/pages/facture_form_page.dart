import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../../../screens/finance/finance_refresh.dart';
import '../../../operation_financiere/domain/entities/categorie_operation.dart';
import '../../../operation_financiere/domain/enums/type_operation.dart';
import '../../../operation_financiere/presentation/providers/categorie_operation_provider.dart';
import '../../domain/entities/fournisseur.dart';
import '../providers/fournisseur_providers.dart';
import 'fournisseur_form_page.dart';

/// Saisie d'une facture reçue.
///
/// C'est cette pièce qui porte la charge, à sa date : le règlement viendra plus
/// tard, et ne changera rien au mois sur lequel la dépense pèse.
class FactureFormPage extends ConsumerStatefulWidget {
  const FactureFormPage({super.key});

  @override
  ConsumerState<FactureFormPage> createState() => _FactureFormPageState();
}

class _FactureFormPageState extends ConsumerState<FactureFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _pieceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  int? _fournisseurId;
  int? _categorieId;
  DateTime _dateFacture = DateTime.now();
  DateTime? _dateEcheance;
  bool _busy = false;
  String? _erreur;

  @override
  void dispose() {
    _montantCtrl.dispose();
    _pieceCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _erreur = null;
    });
    try {
      await ref.read(fournisseurDatasourceProvider).enregistrerFacture(
            fournisseurId: _fournisseurId!,
            montant: double.parse(_montantCtrl.text.trim()),
            numeroPiece: _pieceCtrl.text.trim(),
            categorieId: _categorieId,
            dateFacture: _dateFacture,
            dateEcheance: _dateEcheance,
            description: _descriptionCtrl.text.trim(),
          );
      if (!mounted) return;
      refreshFournisseurs(ref);
      // La charge entre au résultat dès maintenant, et la dette au bilan.
      refreshFinances(ref);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture enregistrée')),
      );
    } catch (e) {
      if (mounted) setState(() => _erreur = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fournisseurs = ref.watch(fournisseursProvider(true));
    final categories = ref.watch(categoriesByTypeProvider(TypeOperation.DEPENSE));

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        title: 'Nouvelle facture',
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
            fournisseurs.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Fournisseurs indisponibles : $e',
                  style: const TextStyle(color: AppColors.error)),
              data: (liste) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PremiumSelectField<int>(
                    value: _fournisseurId,
                    hint: 'Fournisseur',
                    sheetTitle: 'Choisir le fournisseur',
                    isRequired: true,
                    options: liste
                        .map((f) => SelectOption(
                            value: f.id!,
                            label: f.nom,
                            sousTitre: f.type.label))
                        .toList(),
                    onChanged: (v) => setState(() => _fournisseurId = v),
                  ),
                  // Un fournisseur absent de la liste ne doit pas bloquer la
                  // saisie : on peut le créer sans quitter l'écran.
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        final cree = await Navigator.of(context).push<Fournisseur>(
                          MaterialPageRoute(
                              builder: (_) => const FournisseurFormPage()),
                        );
                        if (cree != null) {
                          ref.invalidate(fournisseursProvider);
                          setState(() => _fournisseurId = cree.id);
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Nouveau fournisseur',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            categories.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (liste) => PremiumSelectField<int>(
                value: _categorieId,
                hint: 'Catégorie de charge',
                sheetTitle: 'Catégorie',
                options: liste
                    .map((CategorieOperation c) =>
                        SelectOption(value: c.id, label: c.libelle))
                    .toList(),
                onChanged: (v) => setState(() => _categorieId = v),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _deco('Montant', suffix: 'XOF'),
              validator: (v) {
                final montant = double.tryParse((v ?? '').trim()) ?? 0;
                return montant > 0 ? null : 'Montant obligatoire';
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pieceCtrl,
              decoration: _deco('N° de la pièce du fournisseur'),
            ),
            const SizedBox(height: 12),
            _ChampDate(
              libelle: 'Date de la facture',
              aide: 'C\'est elle qui date la charge',
              date: _dateFacture,
              lastDate: DateTime.now(),
              onChanged: (d) => setState(() => _dateFacture = d),
            ),
            const SizedBox(height: 12),
            _ChampDate(
              libelle: 'Échéance',
              aide: 'À défaut, la facture est due à réception',
              date: _dateEcheance,
              lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              onChanged: (d) => setState(() => _dateEcheance = d),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: _deco('Description'),
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

  InputDecoration _deco(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
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

class _ChampDate extends StatelessWidget {
  final String libelle;
  final String aide;
  final DateTime? date;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;

  const _ChampDate({
    required this.libelle,
    required this.aide,
    required this.date,
    required this.lastDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final choix = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: lastDate,
          locale: const Locale('fr', 'FR'),
        );
        if (choix != null) onChanged(choix);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.label),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.label)),
                  const SizedBox(height: 2),
                  Text(
                      date != null
                          ? DateFormat('dd/MM/yyyy').format(date!)
                          : aide,
                      style: TextStyle(
                          fontSize: 14,
                          color: date != null ? AppColors.dark : AppColors.hint)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: AppColors.hint),
          ],
        ),
      ),
    );
  }
}
