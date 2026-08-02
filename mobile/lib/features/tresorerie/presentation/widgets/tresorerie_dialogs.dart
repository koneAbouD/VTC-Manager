import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/premium_select_field.dart';
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

    return _SheetShell(
      keyboardHeight: keyboardHeight,
      bottomSafe: bottomSafe,
      entete: const _SheetTitle(
        icon: Icons.swap_horiz_rounded,
        accent: _kPrimary,
        title: 'Transfert entre comptes',
        subtitle: 'Déplacer un montant d\'un compte vers un autre',
      ),
      children: [

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

  /// Journée comptée. Aujourd'hui par défaut, mais une caisse oubliée reste
  /// régularisable — et c'est la seule façon de satisfaire la clôture d'un mois
  /// passé, qui exige un comptage daté *dans* le mois.
  DateTime _date = DateTime.now();

  /// Solde théorique **à la date comptée** : c'est à lui que le serveur
  /// comparera le comptage. Tant que la date est aujourd'hui, le solde courant
  /// déjà chargé fait l'affaire ; dès qu'on antidate, il faut le redemander.
  late double _theorique;
  bool _chargementSolde = false;

  /// Dernier relevé en vigueur du compte : c'est lui qui verrouille la
  /// chronologie — aucun comptage ne peut être daté avant lui. L'afficher est
  /// le seul moyen de comprendre un refus, et de le défaire s'il est erroné.
  ClotureCaisseData? _dernierReleve;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _selection = widget.comptes.first;
    _theorique = _selection.solde;
    _chargerDernierReleve();
  }

  Future<void> _chargerDernierReleve() async {
    final compteId = _selection.id;
    List<ClotureCaisseData> releves = const [];
    try {
      releves = await ref
          .read(tresorerieDatasourceProvider)
          .getCloturesCaisse(compteId);
    } catch (_) {
      // Information de confort : son absence ne doit pas empêcher de compter.
    }
    if (!mounted || compteId != _selection.id) return;
    setState(() =>
        _dernierReleve = releves.isNotEmpty ? releves.first : null);
  }

  Future<void> _annulerDernierReleve() async {
    final releve = _dernierReleve;
    if (releve == null) return;

    final motif = await _demanderMotifAnnulation(context);
    if (motif == null || !mounted) return;

    try {
      await ref
          .read(tresorerieDatasourceProvider)
          .annulerClotureCaisse(releve.id, motif);
      refreshFinances(ref);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.message);
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = 'Annulation impossible : $e');
      return;
    }

    if (!mounted) return;
    setState(() => _submitError = null);
    await _chargerDernierReleve();
    if (mounted) _showToast(context, 'Relevé annulé — la journée est rouverte');
  }

  @override
  void dispose() {
    _comptageCtrl.dispose();
    _motifCtrl.dispose();
    super.dispose();
  }

  bool get _estAujourdHui {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  /// Remet le solde théorique en phase avec le compte et la date choisis.
  Future<void> _majTheorique() async {
    if (_estAujourdHui) {
      setState(() {
        _theorique = _selection.solde;
        _chargementSolde = false;
      });
      return;
    }

    final compteId = _selection.id;
    final date = _date;
    setState(() {
      _chargementSolde = true;
      _submitError = null;
    });

    double? solde;
    String? erreur;
    try {
      solde = await ref
          .read(tresorerieDatasourceProvider)
          .getSoldeALaDate(compteId, date);
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (e) {
      erreur = 'Solde à cette date indisponible : $e';
    }

    // Réponse périmée : l'utilisateur a changé de compte ou de date entre-temps.
    if (!mounted || compteId != _selection.id || date != _date) return;
    setState(() {
      _chargementSolde = false;
      if (solde != null) _theorique = solde;
      _submitError = erreur;
    });
  }

  double? get _comptage =>
      double.tryParse(_comptageCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));

  double? get _ecart {
    final c = _comptage;
    return c != null ? c - _theorique : null;
  }

  bool get _motifRequis {
    final e = _ecart;
    return e != null && e != 0;
  }

  bool get _valide => _blocage == null;

  /// Ce qui manque encore pour pouvoir clôturer, `null` si le formulaire est
  /// complet. Un bouton grisé sans explication laisse croire à une panne — le
  /// cas le plus trompeur étant une caisse vide, où l'on n'a pas l'idée de
  /// saisir un montant.
  String? get _blocage {
    if (_chargementSolde) return 'Lecture du solde à cette date…';
    if (_comptage == null) {
      return 'Saisissez le montant compté. Un compte vide se déclare « 0 ».';
    }
    if (_motifRequis && _motifCtrl.text.trim().isEmpty) {
      return 'Le comptage diffère du solde théorique : précisez le motif de '
          'l\'écart.';
    }
    return null;
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
            dateCloture: _date,
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

    return _SheetShell(
      keyboardHeight: keyboardHeight,
      bottomSafe: bottomSafe,
      entete: const _SheetTitle(
        icon: Icons.lock_outline_rounded,
        accent: _kPrimary,
        title: 'Clôture de caisse',
        subtitle: 'Comparer le comptage réel au solde théorique',
      ),
      children: [

          // ── Compte et journée comptée ───────────────────────────────
          _FormCard(
            icon: Icons.account_balance_wallet_outlined,
            accent: _kPrimary,
            title: 'Compte à clôturer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LabeledField(
                  label: 'Compte',
                  isRequired: true,
                  child: _StyledDropdown<CompteAvecSoldeVue>(
                    value: _selection,
                    items: widget.comptes,
                    icon: Icons.payments_outlined,
                    label: (c) => c.libelle,
                    onChanged: (c) {
                      setState(() {
                        _selection = c;
                        _dernierReleve = null;
                      });
                      _majTheorique();
                      _chargerDernierReleve();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Journée comptée',
                  isRequired: true,
                  child: _ChampDateCloture(
                    date: _date,
                    onChanged: (d) {
                      setState(() => _date = d);
                      _majTheorique();
                    },
                  ),
                ),
                if (!_estAujourdHui) ...[
                  const SizedBox(height: 8),
                  const _NoteAntidatage(),
                ],
                if (_dernierReleve != null) ...[
                  const SizedBox(height: 8),
                  _DernierReleve(
                    releve: _dernierReleve!,
                    onAnnuler: _annulerDernierReleve,
                  ),
                ],
              ],
            ),
          ),

          // ── Solde théorique ─────────────────────────────────────────
          _InfoCard(
            titre: 'Solde théorique',
            sousTitre: _estAujourdHui
                ? 'Calculé à partir des mouvements enregistrés'
                : 'Arrêté au ${DateFormat('dd/MM/yyyy').format(_date)}',
            badge: _chargementSolde
                ? '…'
                : CurrencyFormatter.format(_theorique),
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
          if (_blocage != null && !_submitting) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 15, color: _kHint),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _blocage!,
                      style: const TextStyle(
                          fontSize: 12, height: 1.3, color: _kLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
          _SubmitButton(
            label: 'Clôturer la caisse',
            icon: Icons.lock_rounded,
            accent: _kPrimary,
            submitting: _submitting,
            submittingLabel: 'Clôture…',
            onPressed: _valide ? _submit : null,
          ),
      ],
    );
  }
}

/// Dernier relevé en vigueur du compte, et sortie de secours.
///
/// C'est lui qui verrouille la chronologie : aucun comptage ne peut être daté
/// avant. Un relevé saisi à la mauvaise date enfermerait donc l'utilisateur —
/// d'où le retrait, qui rouvre la journée sans effacer le procès-verbal.
class _DernierReleve extends StatelessWidget {
  final ClotureCaisseData releve;
  final VoidCallback onAnnuler;

  const _DernierReleve({required this.releve, required this.onAnnuler});

  @override
  Widget build(BuildContext context) {
    final date = releve.dateCloture;
    final libelle = date != null
        ? DateFormat('dd/MM/yyyy').format(date)
        : 'date inconnue';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 16, color: _kLabel),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Dernier relevé : $libelle — '
              '${CurrencyFormatter.format(releve.soldeCompte)}. '
              'Aucun comptage ne peut être daté avant.',
              style: const TextStyle(
                  fontSize: 12, height: 1.3, color: _kLabel),
            ),
          ),
          TextButton(
            onPressed: onAnnuler,
            style: TextButton.styleFrom(
              foregroundColor: _kError,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retirer',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Demande le motif du retrait — il reste au dossier avec le relevé.
Future<String?> _demanderMotifAnnulation(BuildContext context) async {
  final controller = TextEditingController();
  final motif = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Retirer ce relevé'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Le relevé restera au dossier, marqué de son motif et de son '
            'auteur. Il cessera simplement de faire foi.',
            style: TextStyle(fontSize: 13, height: 1.35, color: _kLabel),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 2,
            minLines: 1,
            style: const TextStyle(fontSize: 15, color: _kDark),
            decoration: _fieldDeco('Ex. : saisi à la mauvaise date'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final saisie = controller.text.trim();
            if (saisie.isEmpty) return;
            Navigator.pop(ctx, saisie);
          },
          style: FilledButton.styleFrom(backgroundColor: _kError),
          child: const Text('Retirer'),
        ),
      ],
    ),
  );
  controller.dispose();
  return motif;
}

/// Journée comptée : aujourd'hui le plus souvent, mais un comptage en retard —
/// ou de fin de mois, saisi après coup — doit rester possible. Jamais future :
/// une caisse ne se compte pas à l'avance.
class _ChampDateCloture extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _ChampDateCloture({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final choix = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          locale: const Locale('fr', 'FR'),
        );
        if (choix != null) onChanged(choix);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 16, color: _kLabel),
            const SizedBox(width: 10),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(
                  fontSize: 15, color: _kDark, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: _kHint),
          ],
        ),
      ),
    );
  }
}

/// Rappel affiché dès que le comptage est antidaté : le comptage verrouille la
/// journée sur ce compte — plus aucune écriture ne pourra y être datée de ce
/// jour-là ou d'avant.
class _NoteAntidatage extends StatelessWidget {
  const _NoteAntidatage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAmber.withValues(alpha: 0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _kAmber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Comptage antidaté : plus aucune écriture ne pourra être '
              'enregistrée sur ce compte à cette date ou avant.',
              style: TextStyle(fontSize: 12, height: 1.3, color: _kLabel),
            ),
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

/// Enveloppe commune des bottom sheets de trésorerie.
///
/// Poignée et titre restent **hors** de la zone défilante : ils forment une
/// prise fixe, sur laquelle le glissement vers le bas ferme la feuille même
/// quand le formulaire est plus haut que l'écran (sans quoi le défilement
/// interne capte le geste).
class _SheetShell extends StatelessWidget {
  final Widget entete;
  final List<Widget> children;
  final double keyboardHeight;
  final double bottomSafe;

  const _SheetShell({
    required this.entete,
    required this.children,
    required this.keyboardHeight,
    required this.bottomSafe,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // La feuille ne monte jamais jusqu'au bord haut : la bande restante
      // reste tactile pour refermer d'un appui à côté.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _DragHandle(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: entete,
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  16, 0, 16, 16 + keyboardHeight + bottomSafe),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return PremiumSelectField<T>(
      value: value,
      isRequired: true,
      accent: _kPrimary,
      options: [
        for (final i in items) SelectOption<T>(value: i, label: label(i)),
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
