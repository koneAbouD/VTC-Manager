import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../../domain/entities/rapports.dart';
import '../providers/tresorerie_providers.dart';
import '../../../../screens/finance/finance_refresh.dart';

// ── Palette (alignée sur la charte AppColors) ───────────────────────────────

const _kPrimary = AppColors.primary; // vert de marque
const _kAmber = AppColors.warning; // écart / attention
const _kFieldFill = AppColors.fieldFill;
const _kHint = AppColors.hint;
const _kLabel = AppColors.label;
const _kBorder = AppColors.border;
const _kDark = AppColors.dark;
const _kError = AppColors.error;

// ── Toast ───────────────────────────────────────────────────────────────────

void _showToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white)),
        ),
      ]),
      backgroundColor: error ? _kError : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: error ? const Duration(seconds: 4) : const Duration(seconds: 2),
    ));
}

// ═══════════════════════════════════════════════════════════════════════════
//  TRANSFERT ENTRE COMPTES
// ═══════════════════════════════════════════════════════════════════════════

/// Ouvre le bottom sheet premium de transfert entre deux comptes de trésorerie.
Future<void> showTransfertDialog(
  BuildContext context,
  WidgetRef ref,
  List<CompteTresorerie> comptes,
) async {
  if (comptes.length < 2) {
    _showToast(context, 'Il faut au moins deux comptes pour transférer',
        error: true);
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _TransfertSheet(comptes: comptes),
  );
}

class _TransfertSheet extends ConsumerStatefulWidget {
  final List<CompteTresorerie> comptes;
  const _TransfertSheet({required this.comptes});

  @override
  ConsumerState<_TransfertSheet> createState() => _TransfertSheetState();
}

class _TransfertSheetState extends ConsumerState<_TransfertSheet> {
  late CompteTresorerie _source;
  late CompteTresorerie _destination;
  final _montantCtrl = TextEditingController();
  final _commentaireCtrl = TextEditingController();

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _source = widget.comptes.first;
    _destination = widget.comptes[1];
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _commentaireCtrl.dispose();
    super.dispose();
  }

  double? get _montant =>
      double.tryParse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));

  bool get _valide {
    final m = _montant;
    return m != null && m > 0 && _source.id != _destination.id;
  }

  void _swap() => setState(() {
        final tmp = _source;
        _source = _destination;
        _destination = tmp;
      });

  Future<void> _submit() async {
    final montant = _montant;
    if (montant == null || montant <= 0) {
      setState(() => _submitError = 'Saisissez un montant valide.');
      return;
    }
    if (_source.id == _destination.id) {
      setState(() =>
          _submitError = 'Les comptes source et destination doivent différer.');
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    String? error;
    try {
      await ref.read(tresorerieDatasourceProvider).createTransfert(
            compteSourceId: _source.id,
            compteDestinationId: _destination.id,
            montant: montant,
            commentaire: _commentaireCtrl.text.trim(),
          );
      refreshFinances(ref);
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Transfert impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitError = error;
    });

    if (error == null) {
      Navigator.pop(context);
      _showToast(
          context, 'Transfert de ${CurrencyFormatter.format(montant)} effectué');
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final memeCompte = _source.id == _destination.id;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight + bottomSafe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DragHandle(),
          const _SheetTitle(
            icon: Icons.swap_horiz_rounded,
            accent: _kPrimary,
            title: 'Transfert entre comptes',
            subtitle: 'Déplacer un montant d\'un compte vers un autre',
          ),
          const SizedBox(height: 14),

          // ── Aperçu source → destination ─────────────────────────────
          _FlowPreview(source: _source, destination: _destination),
          const SizedBox(height: 12),

          // ── Comptes ─────────────────────────────────────────────────
          _FormCard(
            icon: Icons.account_balance_wallet_outlined,
            accent: _kPrimary,
            title: 'Comptes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledField(
                  label: 'Depuis',
                  isRequired: true,
                  child: _StyledDropdown<CompteTresorerie>(
                    value: _source,
                    items: widget.comptes,
                    icon: Icons.arrow_upward_rounded,
                    label: (c) => c.libelle,
                    onChanged: (c) => setState(() => _source = c),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Material(
                      color: _kPrimary.withValues(alpha: 0.10),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _swap,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.swap_vert_rounded,
                              size: 20, color: _kPrimary),
                        ),
                      ),
                    ),
                  ),
                ),
                _LabeledField(
                  label: 'Vers',
                  isRequired: true,
                  child: _StyledDropdown<CompteTresorerie>(
                    value: _destination,
                    items: widget.comptes,
                    icon: Icons.arrow_downward_rounded,
                    label: (c) => c.libelle,
                    onChanged: (c) => setState(() => _destination = c),
                  ),
                ),
                if (memeCompte) ...[
                  const SizedBox(height: 8),
                  const Text('Choisissez deux comptes différents.',
                      style: TextStyle(
                          fontSize: 12,
                          color: _kError,
                          fontWeight: FontWeight.w500)),
                ],
              ],
            ),
          ),

          // ── Détails ─────────────────────────────────────────────────
          _FormCard(
            icon: Icons.tune_rounded,
            accent: _kPrimary,
            title: 'Détails',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledField(
                  label: 'Montant',
                  isRequired: true,
                  child: TextField(
                    controller: _montantCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 15, color: _kDark, fontWeight: FontWeight.w600),
                    decoration: _fieldDeco('0').copyWith(
                      suffixText: 'XOF',
                      suffixStyle: const TextStyle(
                          color: _kLabel,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Commentaire (optionnel)',
                  child: TextField(
                    controller: _commentaireCtrl,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 15, color: _kDark),
                    decoration: _fieldDeco('Motif du transfert…'),
                  ),
                ),
              ],
            ),
          ),

          if (_submitError != null) ...[
            const SizedBox(height: 2),
            AppErrorBanner(
              message: _submitError!,
              onClose: () => setState(() => _submitError = null),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 4),
          _SubmitButton(
            label: 'Transférer',
            icon: Icons.swap_horiz_rounded,
            accent: _kPrimary,
            submitting: _submitting,
            submittingLabel: 'Transfert…',
            onPressed: _valide ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Encart d'aperçu « compte source → compte destination ».
class _FlowPreview extends StatelessWidget {
  final CompteTresorerie source;
  final CompteTresorerie destination;
  const _FlowPreview({required this.source, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          Expanded(child: _FlowEnd(compte: source, isSource: true)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _kPrimary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                size: 16, color: _kPrimary),
          ),
          Expanded(child: _FlowEnd(compte: destination, isSource: false)),
        ],
      ),
    );
  }
}

class _FlowEnd extends StatelessWidget {
  final CompteTresorerie compte;
  final bool isSource;
  const _FlowEnd({required this.compte, required this.isSource});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isSource ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(isSource ? 'Depuis' : 'Vers',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: _kHint)),
        const SizedBox(height: 3),
        Text(
          compte.libelle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isSource ? TextAlign.start : TextAlign.end,
          style: const TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700, color: _kDark),
        ),
        const SizedBox(height: 2),
        Text(
          CurrencyFormatter.format(compte.solde),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: compte.solde < 0 ? _kError : _kLabel),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CLÔTURE DE CAISSE
// ═══════════════════════════════════════════════════════════════════════════

/// Ouvre le bottom sheet premium de clôture de caisse. Le solde théorique est
/// affiché, le comptage saisi, et le motif devient obligatoire dès qu'un écart
/// apparaît.
Future<void> showClotureCaisseDialog(
  BuildContext context,
  WidgetRef ref,
  List<CompteAvecSoldeVue> comptes,
) async {
  if (comptes.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ClotureSheet(comptes: comptes),
  );
}

class _ClotureSheet extends ConsumerStatefulWidget {
  final List<CompteAvecSoldeVue> comptes;
  const _ClotureSheet({required this.comptes});

  @override
  ConsumerState<_ClotureSheet> createState() => _ClotureSheetState();
}

class _ClotureSheetState extends ConsumerState<_ClotureSheet> {
  late CompteAvecSoldeVue _selection;
  final _comptageCtrl = TextEditingController();
  final _motifCtrl = TextEditingController();

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _selection = widget.comptes.first;
  }

  @override
  void dispose() {
    _comptageCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  double? get _comptage =>
      double.tryParse(_comptageCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));

  double? get _ecart {
    final c = _comptage;
    return c != null ? c - _selection.solde : null;
  }

  bool get _motifRequis {
    final e = _ecart;
    return e != null && e != 0;
  }

  bool get _valide {
    if (_comptage == null) return false;
    if (_motifRequis && _motifCtrl.text.trim().isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    final comptage = _comptage;
    if (comptage == null) return;

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    ClotureCaisseData? cloture;
    String? error;
    try {
      cloture = await ref.read(tresorerieDatasourceProvider).cloturerCaisse(
            compteId: _selection.id,
            soldeCompte: comptage,
            motifEcart: _motifCtrl.text.trim(),
          );
      refreshFinances(ref);
    } on ApiException catch (e) {
      error = e.message;
    } catch (e) {
      error = 'Clôture impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitError = error;
    });

    if (error == null && cloture != null) {
      Navigator.pop(context);
      final msg = cloture.ecart == 0
          ? 'Caisse clôturée sans écart'
          : 'Caisse clôturée — écart de ${CurrencyFormatter.format(cloture.ecart)} enregistré';
      _showToast(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final ecart = _ecart;
    final aEcart = ecart != null && ecart != 0;
    final ecartColor = ecart == null || ecart == 0
        ? AppColors.success
        : (ecart < 0 ? _kError : _kAmber);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight + bottomSafe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DragHandle(),
          const _SheetTitle(
            icon: Icons.lock_outline_rounded,
            accent: _kPrimary,
            title: 'Clôture de caisse',
            subtitle: 'Comparer le comptage réel au solde théorique',
          ),
          const SizedBox(height: 14),

          // ── Compte ──────────────────────────────────────────────────
          _FormCard(
            icon: Icons.account_balance_wallet_outlined,
            accent: _kPrimary,
            title: 'Compte à clôturer',
            child: _StyledDropdown<CompteAvecSoldeVue>(
              value: _selection,
              items: widget.comptes,
              icon: Icons.payments_outlined,
              label: (c) => c.libelle,
              onChanged: (c) => setState(() => _selection = c),
            ),
          ),

          // ── Solde théorique ─────────────────────────────────────────
          _InfoCard(
            titre: 'Solde théorique',
            sousTitre: 'Calculé à partir des mouvements enregistrés',
            badge: CurrencyFormatter.format(_selection.solde),
            couleur: _kPrimary,
            icone: Icons.calculate_outlined,
          ),
          const SizedBox(height: 12),

          // ── Comptage ────────────────────────────────────────────────
          _FormCard(
            icon: Icons.point_of_sale_outlined,
            accent: _kPrimary,
            title: 'Comptage réel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledField(
                  label: 'Montant compté',
                  isRequired: true,
                  child: TextField(
                    controller: _comptageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 15, color: _kDark, fontWeight: FontWeight.w600),
                    decoration: _fieldDeco('0').copyWith(
                      suffixText: 'XOF',
                      suffixStyle: const TextStyle(
                          color: _kLabel,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (ecart != null) ...[
                  const SizedBox(height: 14),
                  _EcartBanner(ecart: ecart, color: ecartColor),
                ],
                if (aEcart) ...[
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Motif de l\'écart',
                    isRequired: true,
                    child: TextField(
                      controller: _motifCtrl,
                      maxLines: 2,
                      minLines: 1,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration:
                          _fieldDeco('Expliquez la différence constatée…'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (_submitError != null) ...[
            const SizedBox(height: 2),
            AppErrorBanner(
              message: _submitError!,
              onClose: () => setState(() => _submitError = null),
            ),
            const SizedBox(height: 10),
          ],

          const SizedBox(height: 4),
          _SubmitButton(
            label: 'Clôturer la caisse',
            icon: Icons.lock_rounded,
            accent: _kPrimary,
            submitting: _submitting,
            submittingLabel: 'Clôture…',
            onPressed: _valide ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Bandeau d'écart coloré (vert = aucun écart, rouge = manquant, ambre = surplus).
class _EcartBanner extends StatelessWidget {
  final double ecart;
  final Color color;
  const _EcartBanner({required this.ecart, required this.color});

  @override
  Widget build(BuildContext context) {
    final aucun = ecart == 0;
    final icone = aucun
        ? Icons.check_circle_outline_rounded
        : (ecart < 0
            ? Icons.trending_down_rounded
            : Icons.trending_up_rounded);
    final libelle = aucun
        ? 'Aucun écart'
        : (ecart < 0 ? 'Manquant en caisse' : 'Surplus en caisse');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icone, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(libelle,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
          Text(
            aucun
                ? CurrencyFormatter.format(0)
                : '${ecart > 0 ? '+' : ''}${CurrencyFormatter.format(ecart)}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

/// Vue minimale (id, libellé, solde) passée au dialog de clôture.
class CompteAvecSoldeVue {
  final int id;
  final String libelle;
  final double solde;
  const CompteAvecSoldeVue(
      {required this.id, required this.libelle, required this.solde});
}

// ═══════════════════════════════════════════════════════════════════════════
//  WIDGETS PARTAGÉS (alignés sur vidange_form_dialog / encaissement)
// ═══════════════════════════════════════════════════════════════════════════

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _SheetTitle({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                      letterSpacing: -0.4)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(fontSize: 12, color: _kHint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final String submittingLabel;
  final IconData icon;
  final Color accent;
  final bool submitting;
  final VoidCallback? onPressed;

  const _SubmitButton({
    required this.label,
    required this.submittingLabel,
    required this.icon,
    required this.accent,
    required this.submitting,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton.icon(
        onPressed: submitting ? null : onPressed,
        icon: submitting
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 18),
        label: Text(
          submitting ? submittingLabel : label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final String? badge;
  final Color couleur;
  final IconData icone;

  const _InfoCard({
    required this.titre,
    this.sousTitre,
    this.badge,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: couleur.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icone, size: 18, color: couleur),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titre,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kDark)),
              if (sousTitre != null)
                Text(sousTitre!,
                    style: const TextStyle(fontSize: 11, color: _kHint)),
            ],
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge!,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: couleur),
            ),
          ),
        ],
      ]),
    );
  }
}

class _FormCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final Widget child;

  const _FormCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _kDark,
                      letterSpacing: -0.2)),
            ),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final bool isRequired;
  final Widget child;

  const _LabeledField({
    required this.label,
    this.isRequired = false,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _kLabel)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  final IconData icon;

  const _StyledDropdown({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more_rounded, color: _kHint),
      style: const TextStyle(
          fontSize: 15, color: _kDark, fontWeight: FontWeight.w600),
      decoration: _fieldDeco('').copyWith(
        prefixIcon: Icon(icon, size: 18, color: _kHint),
      ),
      items: [
        for (final i in items)
          DropdownMenuItem<T>(
            value: i,
            child: Text(label(i),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

InputDecoration _fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 15),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
    );
