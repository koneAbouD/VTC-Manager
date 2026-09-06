import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../operation_financiere/domain/entities/element_maintenance.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kPrimary = AppColors.primary;
const _kAccent = Color(0xFFE65100);
const _kDark = Color(0xFF1A1A2E);
const _kBorder = Color(0xFFE3E6EE);
const _kLabel = Color(0xFF6B7280);

/// Ce que l'utilisateur a décidé en clôturant : le coût réel, puis payé sur
/// place ou laissé à payer avec une échéance.
class ChoixCloture {
  final double cout;
  final bool aCredit;
  final DateTime? echeance;

  const ChoixCloture({
    required this.cout,
    required this.aCredit,
    this.echeance,
  });
}

/// Demande le coût réel et le mode de règlement d'une intervention réalisée.
///
/// Deux appelants, deux moments : la fiche d'une maintenance planifiée qu'on
/// clôture, et le formulaire d'une intervention saisie après coup — sa date est
/// passée, elle est donc terminée dès sa création. Le titre, le texte et le
/// libellé du bouton disent laquelle des deux actions est en cours ; tout le
/// reste — coût, comptant ou crédit, aperçu des dettes — est identique.
Future<ChoixCloture?> showTerminerMaintenanceDialog(
  BuildContext context, {
  required String titre,
  required String message,
  required String typeLabel,
  String? partenaireNom,
  List<ElementMaintenance> elements = const [],
  double? coutInitial,
  String validerLabel = 'Confirmer',
  IconData icone = Icons.check_circle_outline_rounded,
}) {
  return showDialog<ChoixCloture>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _TerminerMaintenanceDialog(
      titre: titre,
      message: message,
      typeLabel: typeLabel,
      partenaireNom: partenaireNom,
      elements: elements,
      coutInitial: coutInitial,
      validerLabel: validerLabel,
      icone: icone,
    ),
  );
}

/// Dialogue de clôture d'une maintenance : coût réel, puis la seule question
/// qui change la suite — réglé maintenant, ou à payer ? À crédit, l'écran
/// annonce les dettes qui vont naître, avant de valider.
class _TerminerMaintenanceDialog extends StatefulWidget {
  final String titre;
  final String message;
  final String typeLabel;
  final String? partenaireNom;
  final List<ElementMaintenance> elements;
  final double? coutInitial;
  final String validerLabel;
  final IconData icone;

  const _TerminerMaintenanceDialog({
    required this.titre,
    required this.message,
    required this.typeLabel,
    required this.partenaireNom,
    required this.elements,
    required this.coutInitial,
    required this.validerLabel,
    required this.icone,
  });

  @override
  State<_TerminerMaintenanceDialog> createState() =>
      _TerminerMaintenanceDialogState();
}

class _TerminerMaintenanceDialogState
    extends State<_TerminerMaintenanceDialog> {
  late final TextEditingController _coutCtrl;
  bool _aCredit = false;
  DateTime _echeance = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Le coût des lignes déjà saisies sert de proposition : dans le cas courant
    // il est exact, et il reste modifiable si la facture s'en écarte.
    final propose = widget.coutInitial;
    _coutCtrl = TextEditingController(
      text: propose != null && propose > 0
          ? propose.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _coutCtrl.dispose();
    super.dispose();
  }

  bool get _valide => _coutCtrl.text.trim().isNotEmpty;

  double get _cout =>
      double.tryParse(_coutCtrl.text.replaceAll(',', '.')) ?? 0;

  /// Aperçu de la répartition, calqué sur la règle du serveur : les lignes vont
  /// à leur prestataire, celles qui n'en ont pas au partenaire de
  /// l'intervention, et tout écart avec le coût validé revient à ce dernier.
  List<MapEntry<String, double>> get _dettesPrevues {
    final principal = widget.partenaireNom ?? 'Partenaire à définir';

    final parNom = <String, double>{};
    var totalLignes = 0.0;
    for (final el in widget.elements) {
      final nom = el.partenaireNom ?? principal;
      parNom[nom] = (parNom[nom] ?? 0) + el.montant;
      totalLignes += el.montant;
    }
    final ecart = _cout - totalLignes;
    if (ecart.abs() > 0.5 || parNom.isEmpty) {
      parNom[principal] = (parNom[principal] ?? 0) + ecart;
    }
    return parNom.entries.where((e) => e.value > 0).toList();
  }

  void _confirmer() {
    Navigator.pop(
      context,
      ChoixCloture(
        cout: _cout,
        aCredit: _aCredit,
        echeance: _aCredit ? _echeance : null,
      ),
    );
  }

  Future<void> _choisirEcheance() async {
    // Le champ « Coût réel » a le focus dès l'ouverture : sans cela, le clavier
    // recouvrirait la molette, qui s'ouvre elle aussi par le bas.
    FocusScope.of(context).unfocus();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _echeance,
        firstDate: DateTime.now().subtract(const Duration(days: 365)),
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      ),
    );
    if (picked != null) setState(() => _echeance = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icone,
                        color: AppColors.primaryDark, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.titre,
                            style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: _kDark,
                                letterSpacing: -0.2)),
                        const SizedBox(height: 2),
                        Text(widget.typeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: _kLabel)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.message,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: _kLabel),
              ),
              const SizedBox(height: 16),
              // ── Champ coût réel ────────────────────────────────────────
              TextField(
                controller: _coutCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _kDark),
                decoration: InputDecoration(
                  labelText: 'Coût réel',
                  labelStyle: const TextStyle(color: _kLabel),
                  floatingLabelStyle:
                      const TextStyle(color: AppColors.primaryDark),
                  prefixIcon: const Icon(Icons.payments_outlined,
                      color: _kPrimary, size: 20),
                  suffixText: 'XOF',
                  suffixStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kLabel),
                  filled: true,
                  fillColor: const Color(0xFFF3F6F4),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _kPrimary, width: 1.6),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onSubmitted: (_) {
                  if (_valide) _confirmer();
                },
              ),
              const SizedBox(height: 16),

              // ── Réglé maintenant / à payer ─────────────────────────────
              // La question est posée ici parce que c'est le seul moment où la
              // réponse est connue — et elle décide de tout ce qui suit.
              _SegmentReglement(
                aCredit: _aCredit,
                onChanged: (v) => setState(() => _aCredit = v),
              ),

              if (_aCredit) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: _choisirEcheance,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_outlined,
                            size: 18, color: _kPrimary),
                        const SizedBox(width: 10),
                        const Text('Échéance',
                            style: TextStyle(fontSize: 13.5, color: _kLabel)),
                        const Spacer(),
                        Text(
                          DateFormat('dd MMM yyyy', 'fr_FR').format(_echeance),
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _kDark),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 18, color: _kLabel),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ApercuDettes(dettes: _dettesPrevues),
              ],

              const SizedBox(height: 22),
              // ── Actions ────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kLabel,
                          side: const BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _valide ? _confirmer : null,
                        icon: Icon(
                            _aCredit
                                ? Icons.receipt_long_rounded
                                : Icons.check_rounded,
                            size: 19),
                        label: Text(
                            _aCredit ? 'Créer la dette' : widget.validerLabel,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          disabledBackgroundColor: _kBorder,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sélecteur « réglé / à payer » ────────────────────────────────────────────
// Deux pavés côte à côte plutôt qu'un interrupteur : chaque issue est nommée,
// et l'on voit ce qu'on choisit sans avoir à deviner ce que « oui » signifie.
class _SegmentReglement extends StatelessWidget {
  final bool aCredit;
  final ValueChanged<bool> onChanged;

  const _SegmentReglement({required this.aCredit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OptionReglement(
            icone: Icons.payments_outlined,
            titre: 'Payer',
            sousTitre: 'Sort de la caisse',
            actif: !aCredit,
            couleur: _kPrimary,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OptionReglement(
            icone: Icons.schedule_outlined,
            titre: 'À payer',
            sousTitre: 'Crée une dette',
            actif: aCredit,
            couleur: _kAccent,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _OptionReglement extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String sousTitre;
  final bool actif;
  final Color couleur;
  final VoidCallback onTap;

  const _OptionReglement({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.actif,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color:
              actif ? couleur.withValues(alpha: 0.10) : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: actif ? couleur : _kBorder,
            width: actif ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, size: 19, color: actif ? couleur : _kLabel),
            const SizedBox(height: 6),
            Text(titre,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: actif ? couleur : _kDark)),
            const SizedBox(height: 1),
            Text(sousTitre,
                style: const TextStyle(fontSize: 11.5, color: _kLabel)),
          ],
        ),
      ),
    );
  }
}

// ── Aperçu des dettes à créer ────────────────────────────────────────────────
// Le récapitulatif est la contrepartie du choix « à payer » : on ne valide pas
// une dette sans savoir envers qui, ni de combien.
class _ApercuDettes extends StatelessWidget {
  final List<MapEntry<String, double>> dettes;

  const _ApercuDettes({required this.dettes});

  @override
  Widget build(BuildContext context) {
    if (dettes.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _kAccent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dettes.length == 1
                ? 'Une dette sera créée :'
                : '${dettes.length} dettes seront créées :',
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: _kAccent),
          ),
          const SizedBox(height: 8),
          for (final d in dettes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(d.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: _kDark)),
                  ),
                  Text(fmt.format(d.value),
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kDark)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
