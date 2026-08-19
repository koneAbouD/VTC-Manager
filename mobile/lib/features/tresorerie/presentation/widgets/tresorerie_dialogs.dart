import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';
import '../../../../core/widgets/premium_select_field.dart';
import '../../domain/entities/compte_tresorerie.dart';
import '../../domain/entities/rapports.dart';
import '../providers/tresorerie_providers.dart';
import '../../../../screens/finance/finance_refresh.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
//
// L'identité reste celle de la charte : le vert de marque porte l'accent, le
// vert sombre confirme. Trois valeurs seulement sont empruntées à
// `encaissement_ligne_dialog` — le gris de remplissage des champs, celui de
// leur bordure, et un rouge d'erreur plus vif — pour que les champs de saisie
// aient la même matière d'un formulaire financier à l'autre.

const _kPrimary = AppColors.primary; // vert de marque
const _kAmber = AppColors.warning; // écart / attention
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint = AppColors.hint;
const _kLabel = AppColors.label;
const _kBorder = Color(0xFFE3E6EE);
const _kDark = AppColors.dark;
const _kError = Color(0xFFE03131);

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
    // Valeur d'attente le temps que le serveur réponde : le solde de la liste
    // n'est qu'un ordre de grandeur, jamais celui auquel la clôture comparera.
    _theorique = _selection.solde;
    _majTheorique();
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

  /// Ouvre l'historique du compte. Le retrait s'y fait, sous les yeux de qui
  /// le décide : la liste montre ce qu'on défait, ce qu'il reste, et pourquoi
  /// un seul relevé porte un bouton.
  Future<void> _ouvrirHistorique() async {
    final aRetire = await showHistoriqueRelevesDialog(
      context,
      ref,
      compteId: _selection.id,
      libelleCompte: _selection.libelle,
    );
    if (!mounted || !aRetire) return;

    // L'extourne de l'ajustement vient de ramener le solde théorique de la
    // journée à ce qu'il était avant le comptage retiré : le relire, sans quoi
    // l'écran continuerait d'annoncer le solde que ce comptage avait imposé.
    setState(() => _submitError = null);
    await Future.wait([_majTheorique(), _chargerDernierReleve()]);
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
  ///
  /// Toujours demandé au serveur, y compris pour aujourd'hui : le solde porté
  /// par la liste des comptes est celui de l'écran d'où l'on vient, et rien ne
  /// garantit qu'il vaille encore. C'est le solde *arrêté à la date comptée*
  /// que la clôture opposera au comptage — annoncer l'autre, c'est promettre un
  /// écart nul là où le serveur en verra un, et exiger ensuite un motif dont le
  /// champ n'est même pas affiché.
  Future<void> _majTheorique() async {
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
    // Solde que le serveur a réellement opposé au comptage, quand il diffère de
    // celui qu'affichait l'écran.
    double? theoriqueServeur;
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
      if (e.body?['error'] == 'MOTIF_ECART_OBLIGATOIRE') {
        theoriqueServeur = _detailNumerique(e, 'soldeTheorique');
        if (theoriqueServeur != null) {
          error = 'Le solde théorique arrêté à cette date est de '
              '${CurrencyFormatter.format(theoriqueServeur)}, et non '
              '${CurrencyFormatter.format(_theorique)}. L\'écart avec votre '
              'comptage doit être motivé.';
        }
      }
    } catch (e) {
      error = 'Clôture impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitError = error;
      // Réaligner le solde affiché sur celui du serveur fait apparaître l'écart
      // — et avec lui le champ motif, qui restait caché tant que l'écran se
      // croyait juste. Sans cela, l'erreur exige une saisie impossible.
      if (theoriqueServeur != null) _theorique = theoriqueServeur;
    });

    if (error == null && cloture != null) {
      Navigator.pop(context);
      final msg = cloture.ecart == 0
          ? 'Caisse clôturée sans écart'
          : 'Caisse clôturée — écart de ${CurrencyFormatter.format(cloture.ecart)} enregistré';
      _showToast(context, msg);
    }
  }

  /// Lit une donnée chiffrée jointe à l'erreur, sous la forme « clé:valeur ».
  /// Ces détails sont destinés au code, pas à l'écran : ils permettent ici de
  /// corriger ce que l'écran affichait plutôt que de s'en tenir à un refus.
  double? _detailNumerique(ApiException e, String cle) {
    final details = (e.body?['details'] as List?)?.whereType<String>() ?? const [];
    for (final d in details) {
      if (d.startsWith('$cle:')) {
        return double.tryParse(d.substring(cle.length + 1).trim());
      }
    }
    return null;
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
                    onHistorique: _ouvrirHistorique,
                  ),
                ],
              ],
            ),
          ),

          // ── Comptage ────────────────────────────────────────────────
          //
          // Solde théorique, comptage et motif tiennent dans une seule carte :
          // les trois nombres ne se lisent que les uns par rapport aux autres.
          // Séparer la référence de la saisie obligeait à faire l'aller-retour
          // du regard au moment précis où l'on compare.
          _FormCard(
            icon: Icons.point_of_sale_outlined,
            accent: _kPrimary,
            title: 'Comptage de la caisse',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SoldeTheorique(
                  montant: _theorique,
                  date: _date,
                  chargement: _chargementSolde,
                ),
                const SizedBox(height: 14),
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
                  const _SuiteEcart(),
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
                      decoration: _fieldDeco(
                          'Ex. : appoint non enregistré, erreur de rendu'),
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

/// Dernier relevé en vigueur du compte, et porte vers l'historique.
///
/// C'est lui qui verrouille la chronologie : aucun comptage ne peut être daté
/// avant. Un relevé saisi à la mauvaise date enfermerait donc l'utilisateur —
/// d'où le retrait, qui rouvre la journée sans effacer le procès-verbal. Mais
/// ce retrait se décide dans l'historique, où l'on voit ce qu'on défait : agir
/// depuis ce bandeau ne montrait rien, et le relevé suivant qui prenait la
/// place du retiré passait pour un échec.
class _DernierReleve extends StatelessWidget {
  final ClotureCaisseData releve;
  final VoidCallback onHistorique;

  const _DernierReleve({required this.releve, required this.onHistorique});

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
            onPressed: onHistorique,
            style: TextButton.styleFrom(
              foregroundColor: _kPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Voir les relevés',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Journée comptée : aujourd'hui le plus souvent, mais un comptage en retard —
/// ou de fin de mois, saisi après coup — doit rester possible. Jamais future :
/// une caisse ne se compte pas à l'avance.
class _ChampDateCloture extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _ChampDateCloture({required this.date, required this.onChanged});

  bool get _estAujourdHui {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        // Même molette premium que partout ailleurs dans l'app — sélecteur de
        // mois de la clôture mensuelle compris. Le calendrier Material natif
        // était le seul de ce module à jurer avec le reste.
        final choix = await showDialog<DateTime>(
          context: context,
          builder: (_) => SingleDatePickerDialog(
            initialDate: date,
            firstDate: DateTime(2020),
            // Une caisse ne se compte pas à l'avance : le serveur refuse une
            // date future, la molette ne la propose pas.
            lastDate: DateTime.now(),
          ),
        );
        if (choix != null) onChanged(choix);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // Même habillage que les champs de saisie voisins : fond plein, sans
        // bordure. Un cadre au repos ferait de la date le seul champ encadré
        // du formulaire.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('dd/MM/yyyy').format(date),
                style: const TextStyle(fontSize: 15, color: _kDark),
              ),
            ),
            // Le cas ordinaire se signale lui-même : c'est l'antidatage qui
            // engage, et qu'il faut remarquer.
            if (_estAujourdHui)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Text("Aujourd'hui",
                    style: TextStyle(fontSize: 12, color: _kHint)),
              ),
            const Icon(Icons.calendar_today_rounded, size: 16, color: _kLabel),
          ],
        ),
      ),
    );
  }
}

/// Ce qu'un écart validé déclenche.
///
/// Valider une différence ne la solde pas : elle part en compte d'attente et
/// devra être tranchée — l'entreprise la supporte, ou le responsable rembourse
/// — faute de quoi le mois où elle tombe refusera d'être clôturé. Le dire ici
/// évite de découvrir la tâche des semaines plus tard, devant un refus de
/// clôture qu'on ne s'explique pas.
class _SuiteEcart extends StatelessWidget {
  const _SuiteEcart();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kAmber.withValues(alpha: 0.22)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.balance_rounded, size: 15, color: _kAmber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'La caisse sera réalignée sur votre comptage, mais le résultat '
              'ne bougera pas : l\'écart part en attente et restera à trancher '
              'depuis « Écarts de caisse ». Tant qu\'il attend, le mois où il '
              'tombe ne pourra pas être clôturé.',
              style: TextStyle(fontSize: 12, height: 1.35, color: _kLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Solde théorique, à l'intérieur de la carte de comptage.
///
/// C'est la référence contre laquelle le montant saisi juste en dessous sera
/// comparé — et le nombre que l'écran doit dire juste, sous peine d'annoncer un
/// écart nul là où le serveur en verra un. Il porte donc toujours sa date
/// d'arrêté, aujourd'hui compris.
class _SoldeTheorique extends StatelessWidget {
  final double montant;
  final DateTime date;
  final bool chargement;

  const _SoldeTheorique({
    required this.montant,
    required this.date,
    required this.chargement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _kPrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kPrimary.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calculate_outlined, size: 18, color: _kPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solde théorique',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
                const SizedBox(height: 2),
                Text('Arrêté au ${DateFormat('dd/MM/yyyy').format(date)}',
                    style: const TextStyle(fontSize: 11.5, color: _kHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (chargement)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary))
          else
            Text(CurrencyFormatter.format(montant),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: _kPrimary)),
        ],
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
//  HISTORIQUE DES RELEVÉS D'UN COMPTE
// ═══════════════════════════════════════════════════════════════════════════

/// Ouvre l'historique des relevés d'un compte. Rend `true` si au moins un
/// relevé a été retiré : l'appelant a alors un solde théorique et un dernier
/// relevé périmés.
///
/// C'est ici que se fait le retrait, et non plus depuis le seul bandeau du
/// dernier relevé. Retirer à l'aveugle un relevé parmi plusieurs ne se
/// distinguait pas d'un échec : le suivant réapparaissait à la même place, avec
/// souvent la même date, et rien ne disait combien il en restait.
Future<bool> showHistoriqueRelevesDialog(
  BuildContext context,
  WidgetRef ref, {
  required int compteId,
  required String libelleCompte,
}) async {
  final retire = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _HistoriqueSheet(compteId: compteId, libelleCompte: libelleCompte),
  );
  return retire ?? false;
}

class _HistoriqueSheet extends ConsumerStatefulWidget {
  final int compteId;
  final String libelleCompte;

  const _HistoriqueSheet(
      {required this.compteId, required this.libelleCompte});

  @override
  ConsumerState<_HistoriqueSheet> createState() => _HistoriqueSheetState();
}

class _HistoriqueSheetState extends ConsumerState<_HistoriqueSheet> {
  List<ClotureCaisseData>? _releves;
  String? _erreur;
  bool _chargement = true;
  int? _enCours;

  /// Vrai dès qu'un retrait a abouti : le sheet de comptage devra relire son
  /// solde théorique, que l'extourne vient de changer.
  bool _aRetire = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _chargement = true);
    List<ClotureCaisseData>? releves;
    String? erreur;
    try {
      releves = await ref
          .read(tresorerieDatasourceProvider)
          .getCloturesCaisse(widget.compteId, inclureAnnules: true);
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (e) {
      erreur = 'Historique indisponible : $e';
    }
    if (!mounted) return;
    setState(() {
      _chargement = false;
      _releves = releves;
      _erreur = erreur;
    });
  }

  /// Seul le relevé en vigueur le plus récent se retire : un comptage
  /// postérieur a été fait sur un solde où l'ajustement de celui-ci était déjà
  /// compris. Le serveur refuse l'ordre inverse ; l'écran ne le propose pas.
  int? get _idRetirable {
    for (final r in _releves ?? const <ClotureCaisseData>[]) {
      if (!r.estAnnule) return r.id;
    }
    return null;
  }

  /// Défait l'arbitrage rendu sur un écart : ses écritures sont contre-passées
  /// et l'écart redevient à trancher. La décision se prend souvent avant
  /// d'avoir tout compris — le manquant du mardi s'explique le jeudi.
  Future<void> _desimputer(ClotureCaisseData releve, String motif) async {
    FocusScope.of(context).unfocus();

    setState(() {
      _enCours = releve.id;
      _erreur = null;
    });

    String? erreur;
    try {
      await ref
          .read(tresorerieDatasourceProvider)
          .annulerImputationEcart(releve.id, motif);
      refreshFinances(ref);
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (e) {
      erreur = 'Retour sur l\'imputation impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _enCours = null;
      _erreur = erreur;
    });
    if (erreur == null) {
      await _charger();
      if (mounted) {
        _showToast(context, 'Imputation défaite — l\'écart est à trancher');
      }
    }
  }

  Future<void> _retirer(ClotureCaisseData releve, String motif) async {
    // Le clavier a fait son office : le refermer avant l'aller-retour évite que
    // la liste se recompose sous un panneau qui n'a plus de champ où écrire.
    FocusScope.of(context).unfocus();

    setState(() {
      _enCours = releve.id;
      _erreur = null;
    });

    String? erreur;
    try {
      await ref
          .read(tresorerieDatasourceProvider)
          .annulerClotureCaisse(releve.id, motif);
      refreshFinances(ref);
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (e) {
      erreur = 'Retrait impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _enCours = null;
      _erreur = erreur;
      if (erreur == null) _aRetire = true;
    });
    if (erreur == null) {
      await _charger();
      if (mounted) _showToast(context, 'Relevé retiré — la journée est rouverte');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Le motif se saisit désormais dans la carte : sans cette réserve, le
    // clavier recouvrirait le champ au moment où l'on y écrit.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final releves = _releves ?? const <ClotureCaisseData>[];
    final retirable = _idRetirable;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _aRetire);
      },
      child: _SheetShell(
        keyboardHeight: keyboardHeight,
        bottomSafe: bottomSafe,
        entete: _SheetTitle(
          icon: Icons.history_rounded,
          accent: _kPrimary,
          title: 'Relevés de caisse',
          subtitle: widget.libelleCompte,
        ),
        children: [
          if (_erreur != null) ...[
            AppErrorBanner(
              message: _erreur!,
              onClose: () => setState(() => _erreur = null),
            ),
            const SizedBox(height: 12),
          ],
          if (_chargement)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (releves.isEmpty)
            const _EtatVide(
              icone: Icons.inbox_outlined,
              titre: 'Aucun relevé',
              texte: 'Ce compte n\'a jamais été compté. Aucune journée n\'y est '
                  'donc fermée.',
              couleur: _kHint,
            )
          else ...[
            const _NoteChronologie(),
            const SizedBox(height: 12),
            for (final releve in releves) ...[
              _CarteReleve(
                // Sans clé, l'état de saisie s'apparie par position : un motif
                // écrit ici réapparaîtrait sur le relevé voisin dès que la
                // liste se recompose.
                key: ValueKey(releve.id),
                releve: releve,
                retirable: releve.id == retirable,
                occupe: _enCours == releve.id,
                gele: _enCours != null && _enCours != releve.id,
                onRetirer: (motif) => _retirer(releve, motif),
                onDesimputer: (motif) => _desimputer(releve, motif),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// Pourquoi un seul relevé porte un bouton. Sans ce rappel, l'absence de
/// bouton sur les autres passerait pour une panne.
class _NoteChronologie extends StatelessWidget {
  const _NoteChronologie();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: _kHint),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Les relevés se défont dans l\'ordre inverse où ils ont été '
              'posés : seul le plus récent encore en vigueur peut être retiré. '
              'Pour rouvrir une journée ancienne, remontez de proche en proche.',
              style: TextStyle(fontSize: 12.5, height: 1.35, color: _kLabel),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un relevé de l'historique. Retiré, il reste affiché — grisé, barré de son
/// motif : c'est un procès-verbal, il ne disparaît pas du dossier.
class _CarteReleve extends StatefulWidget {
  final ClotureCaisseData releve;
  final bool retirable;
  final bool occupe;
  final bool gele;
  final ValueChanged<String> onRetirer;

  /// Revenir sur l'arbitrage rendu sur l'écart. Proposé sur tout relevé en
  /// vigueur dont l'écart a été tranché, quel que soit son rang dans la série :
  /// les écritures d'imputation ne mouvementent aucune caisse, les défaire ne
  /// fait donc mentir aucun comptage postérieur.
  final ValueChanged<String> onDesimputer;

  const _CarteReleve({
    super.key,
    required this.releve,
    required this.retirable,
    required this.occupe,
    required this.gele,
    required this.onRetirer,
    required this.onDesimputer,
  });

  @override
  State<_CarteReleve> createState() => _CarteReleveState();
}

class _CarteReleveState extends State<_CarteReleve> {
  /// Vrai quand le retrait est engagé : le motif se saisit alors dans la carte,
  /// sous la date et le montant du relevé qu'on s'apprête à défaire. Une boîte
  /// de dialogue les aurait masqués au moment d'écrire pourquoi.
  bool _retraitEngage = false;
  final _motifCtrl = TextEditingController();

  /// Même mécanique pour le retour sur imputation : le motif s'écrit sous la
  /// décision qu'on s'apprête à défaire, pas dans une boîte qui la masquerait.
  bool _desimputationEngagee = false;
  final _motifImputationCtrl = TextEditingController();

  @override
  void dispose() {
    _motifCtrl.dispose();
    _motifImputationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final releve = widget.releve;
    final retirable = widget.retirable;
    final occupe = widget.occupe;
    final gele = widget.gele;
    final annule = releve.estAnnule;
    final aEcart = releve.ecart != 0;
    // Un écart tranché a produit des écritures : on peut revenir dessus tant
    // que le relevé fait foi.
    final ecartImpute = releve.imputationStatut == 'PERTE' ||
        releve.imputationStatut == 'RECOUVREE';
    final couleurEcart = !aEcart
        ? AppColors.success
        : (releve.estManquant ? _kError : _kAmber);
    final date = releve.dateCloture;

    return Opacity(
      opacity: annule ? 0.62 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: annule
                  ? _kBorder
                  : (aEcart
                      ? couleurEcart.withValues(alpha: 0.25)
                      : _kBorder)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  date != null
                      ? DateFormat('dd/MM/yyyy').format(date)
                      : 'date inconnue',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: annule ? _kLabel : _kDark,
                    decoration: annule ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(width: 8),
                if (annule)
                  const _Etiquette(texte: 'Retiré', couleur: _kHint)
                else if (releve.attendImputation)
                  const _Etiquette(texte: 'Écart à trancher', couleur: _kAmber)
                else if (releve.imputationStatut == 'PERTE')
                  const _Etiquette(texte: 'Écart supporté', couleur: _kHint)
                else if (releve.imputationStatut == 'RECOUVREE')
                  const _Etiquette(texte: 'Écart à rembourser', couleur: _kHint),
                const Spacer(),
                Text(
                  CurrencyFormatter.format(releve.soldeCompte),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: annule ? _kLabel : _kDark),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _LigneInfo(
              icone: Icons.calculate_outlined,
              texte: 'Théorique '
                  '${CurrencyFormatter.format(releve.soldeTheorique)} — '
                  '${aEcart ? 'écart ${releve.ecart > 0 ? '+' : ''}${CurrencyFormatter.format(releve.ecart)}' : 'aucun écart'}',
            ),
            if (aEcart && (releve.motifEcart ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              _LigneInfo(
                  icone: Icons.notes_rounded,
                  texte: 'Motif : ${releve.motifEcart}'),
            ],
            if (annule) ...[
              const SizedBox(height: 6),
              _LigneInfo(
                icone: Icons.undo_rounded,
                texte: 'Retiré par ${releve.annulePar ?? 'inconnu'}'
                    '${(releve.motifAnnulation ?? '').isNotEmpty ? ' — ${releve.motifAnnulation}' : ''}',
              ),
            ],
            // ── Revenir sur l'imputation ─────────────────────────────
            //
            // Proposé sur tout relevé en vigueur dont l'écart a été tranché,
            // même s'il n'est pas le dernier : ces écritures ne mouvementent
            // aucune caisse, les défaire ne fait mentir aucun comptage.
            if (!annule && ecartImpute) ...[
              const SizedBox(height: 12),
              // Un seul indicateur par carte : quand le retrait est proposé,
              // c'est son bloc qui le porte.
              if (occupe && !retirable)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2)),
                  ),
                )
              else if (!occupe) ...[
                Align(
                  alignment: Alignment.centerRight,
                  child: _desimputationEngagee
                      ? FilledButton.icon(
                          onPressed: gele
                              ? null
                              : () =>
                                  setState(() => _desimputationEngagee = false),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Annuler le retour',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kAmber,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: gele
                              ? null
                              : () =>
                                  setState(() => _desimputationEngagee = true),
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text('Revenir sur l\'imputation',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kAmber,
                            side: BorderSide(
                                color: _kAmber.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
                if (_desimputationEngagee) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kAmber.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _kAmber.withValues(alpha: 0.20)),
                    ),
                    child: const Text(
                      'Les écritures passées lors de l\'imputation seront '
                      'contre-passées, à la date du relevé. L\'écart redeviendra '
                      'à trancher : vous pourrez décider à nouveau.',
                      style: TextStyle(
                          fontSize: 12, height: 1.35, color: _kLabel),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LabeledField(
                    label: 'Motif du retour',
                    isRequired: true,
                    child: TextField(
                      controller: _motifImputationCtrl,
                      maxLines: 2,
                      minLines: 1,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco(
                          'Ex. : le manquant s\'explique, recette saisie deux fois'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _motifImputationCtrl.text.trim().isEmpty || gele
                          ? null
                          : () => widget
                              .onDesimputer(_motifImputationCtrl.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kAmber,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirmer le retour',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ],
            if (retirable) ...[
              const SizedBox(height: 12),
              if (occupe)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2)),
                  ),
                )
              else ...[
                Align(
                  alignment: Alignment.centerRight,
                  // Retaper le bouton referme la saisie : on peut renoncer sans
                  // quitter la liste. Le motif déjà écrit est conservé.
                  child: _retraitEngage
                      ? FilledButton.icon(
                          onPressed: gele
                              ? null
                              : () => setState(() => _retraitEngage = false),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Annuler le retrait',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700)),
                          style: FilledButton.styleFrom(
                            backgroundColor: _kError,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: gele
                              ? null
                              : () => setState(() => _retraitEngage = true),
                          icon: const Icon(Icons.undo_rounded, size: 16),
                          label: const Text('Retirer ce relevé',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kError,
                            side: BorderSide(
                                color: _kError.withValues(alpha: 0.35)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                ),
                if (_retraitEngage) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kError.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _kError.withValues(alpha: 0.20)),
                    ),
                    child: const Text(
                      'Le relevé restera au dossier, marqué de son motif et de '
                      'son auteur. Il cessera simplement de faire foi, et la '
                      'journée se rouvrira au recomptage.',
                      style: TextStyle(
                          fontSize: 12, height: 1.35, color: _kLabel),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _LabeledField(
                    label: 'Motif du retrait',
                    isRequired: true,
                    child: TextField(
                      controller: _motifCtrl,
                      maxLines: 2,
                      minLines: 1,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 15, color: _kDark),
                      decoration: _fieldDeco('Ex. : saisi à la mauvaise date'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      // Le motif est obligatoire côté serveur : le bouton reste
                      // inerte tant qu'il manque, plutôt que d'aller chercher
                      // un refus.
                      onPressed: _motifCtrl.text.trim().isEmpty || gele
                          ? null
                          : () => widget.onRetirer(_motifCtrl.text.trim()),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kError,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Confirmer le retrait',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  final Color couleur;
  const _Etiquette({required this.texte, required this.couleur});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(texte,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w700, color: couleur)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  IMPUTATION DES ÉCARTS DE CAISSE
// ═══════════════════════════════════════════════════════════════════════════

/// Ouvre la liste des écarts de caisse restés sans décision.
///
/// Un écart constaté au comptage dort en compte d'attente : la trésorerie a été
/// réalignée sur ce qui a été compté — l'argent réel est un fait — mais le
/// résultat n'a pas bougé, faute de savoir d'où vient la différence. Trancher,
/// c'est dire qui la supporte. Tant qu'un écart attend, le mois où il tombe
/// refuse d'être clôturé : publier un résultat qu'on sait incomplet n'aurait
/// pas de sens.
Future<void> showEcartsCaisseDialog(
  BuildContext context,
  WidgetRef ref,
  List<CompteAvecSoldeVue> comptes,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.scaffold,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EcartsSheet(comptes: comptes),
  );
}

class _EcartsSheet extends ConsumerStatefulWidget {
  final List<CompteAvecSoldeVue> comptes;
  const _EcartsSheet({required this.comptes});

  @override
  ConsumerState<_EcartsSheet> createState() => _EcartsSheetState();
}

class _EcartsSheetState extends ConsumerState<_EcartsSheet> {
  /// Écart en cours de traitement : ses deux boutons se figent le temps de
  /// l'aller-retour, les autres cartes restent utilisables.
  int? _enCours;
  String? _erreur;

  String _libelleCompte(int? compteId) {
    for (final c in widget.comptes) {
      if (c.id == compteId) return c.libelle;
    }
    return 'Compte';
  }

  Future<void> _imputer(
      ClotureCaisseData ecart, String decision, String motif) async {
    // Le clavier a fait son office : le refermer avant l'aller-retour évite
    // que la liste se recompose sous un panneau qui n'a plus de champ où
    // écrire.
    FocusScope.of(context).unfocus();

    setState(() {
      _enCours = ecart.id;
      _erreur = null;
    });

    String? erreur;
    try {
      await ref
          .read(tresorerieDatasourceProvider)
          .imputerEcartCaisse(ecart.id, decision, motif);
      refreshFinances(ref);
    } on ApiException catch (e) {
      erreur = e.message;
    } catch (e) {
      erreur = 'Imputation impossible : $e';
    }

    if (!mounted) return;
    setState(() {
      _enCours = null;
      _erreur = erreur;
    });
    if (erreur == null) {
      // Prudence dans le libellé : cet écart-là ne bloque plus, mais le mois
      // peut buter sur un autre, ou sur une caisse jamais comptée.
      _showToast(context, 'Écart imputé — il ne bloque plus la clôture');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Le motif se saisit désormais dans la carte : sans cette réserve, le
    // clavier recouvrirait le champ au moment où l'on y écrit.
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final asyncEcarts = ref.watch(ecartsEnAttenteProvider);

    return _SheetShell(
      keyboardHeight: keyboardHeight,
      bottomSafe: bottomSafe,
      entete: const _SheetTitle(
        icon: Icons.balance_rounded,
        accent: _kAmber,
        title: 'Écarts de caisse',
        subtitle: 'Trancher les différences constatées au comptage',
      ),
      children: [
        if (_erreur != null) ...[
          AppErrorBanner(
            message: _erreur!,
            onClose: () => setState(() => _erreur = null),
          ),
          const SizedBox(height: 12),
        ],
        asyncEcarts.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => _EtatVide(
            icone: Icons.cloud_off_rounded,
            titre: 'Liste indisponible',
            texte: messageFromError(e),
            couleur: _kError,
          ),
          data: (ecarts) => ecarts.isEmpty
              ? const _EtatVide(
                  icone: Icons.verified_outlined,
                  titre: 'Aucun écart en attente',
                  texte: 'Toutes les différences constatées ont été tranchées. '
                      'Rien ne s\'oppose de ce côté à la clôture d\'un mois.',
                  couleur: AppColors.success,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _NoteImputation(),
                    const SizedBox(height: 12),
                    for (final ecart in ecarts) ...[
                      _CarteEcart(
                        // Sans clé, la décision et le motif d'un écart imputé
                        // se reporteraient sur l'écart suivant, qui prend sa
                        // place dès que la liste se réduit.
                        key: ValueKey(ecart.id),
                        ecart: ecart,
                        libelleCompte: _libelleCompte(ecart.compteId),
                        occupe: _enCours == ecart.id,
                        gele: _enCours != null && _enCours != ecart.id,
                        onImputer: (decision, motif) =>
                            _imputer(ecart, decision, motif),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Ce que chaque décision engage. Sans ce rappel, le choix se ferait sur deux
/// mots dont ni l'un ni l'autre ne dit son effet comptable.
class _NoteImputation extends StatelessWidget {
  const _NoteImputation();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _kFieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'La caisse a déjà été réalignée sur ce qui a été compté. Il reste '
            'à dire qui supporte la différence :',
            style: TextStyle(fontSize: 12.5, height: 1.35, color: _kLabel),
          ),
          SizedBox(height: 8),
          _PuceNote(
            texte: 'L\'entreprise supporte — la différence entre au résultat, '
                'en charge si c\'est un manquant, en produit si c\'est un '
                'surplus.',
          ),
          SizedBox(height: 6),
          _PuceNote(
            texte: 'À rembourser — la somme devient une créance sur le '
                'responsable du fonds ; elle ne pèse pas sur le résultat.',
          ),
        ],
      ),
    );
  }
}

class _PuceNote extends StatelessWidget {
  final String texte;
  const _PuceNote({required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Icon(Icons.circle, size: 5, color: _kHint),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texte,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.35, color: _kLabel)),
        ),
      ],
    );
  }
}

/// Un écart à trancher : ce qui a été constaté, par qui, et les deux issues.
///
/// La décision et son motif se prennent **dans la carte**, sans boîte de
/// dialogue : choisir une issue fait apparaître ce qu'elle engage et le champ
/// de motif, sous les yeux du montant et de la date qui la justifient. Une
/// popup les aurait masqués au moment précis où l'on écrit pourquoi.
class _CarteEcart extends StatefulWidget {
  final ClotureCaisseData ecart;
  final String libelleCompte;
  final bool occupe;
  final bool gele;
  final void Function(String decision, String motif) onImputer;

  const _CarteEcart({
    super.key,
    required this.ecart,
    required this.libelleCompte,
    required this.occupe,
    required this.gele,
    required this.onImputer,
  });

  @override
  State<_CarteEcart> createState() => _CarteEcartState();
}

class _CarteEcartState extends State<_CarteEcart> {
  /// `PERTE`, `RECOUVREE`, ou null tant que rien n'est choisi : le champ motif
  /// n'a alors pas lieu d'être, puisqu'on ne sait pas encore quoi motiver.
  String? _decision;
  final _motifCtrl = TextEditingController();

  @override
  void dispose() {
    _motifCtrl.dispose();
    super.dispose();
  }

  bool get _perte => _decision == 'PERTE';

  /// Retaper l'issue déjà choisie la relâche : on peut revenir sur son choix
  /// sans quitter la carte. Le motif déjà écrit est conservé — hésiter sur
  /// l'issue ne devrait pas coûter la phrase qu'on vient de taper.
  void _choisir(String decision) {
    setState(() => _decision = _decision == decision ? null : decision);
  }

  String get _explication => _perte
      ? (widget.ecart.estManquant
          ? 'Le manquant devient une charge du mois du comptage : il pèse sur '
              'le résultat, et personne n\'est appelé à rembourser.'
          : 'Le surplus devient un produit du mois du comptage : il entre au '
              'résultat.')
      : 'La somme devient une créance sur le responsable du fonds. Elle ne '
          'pèse pas sur le résultat ; son remboursement se saisira ensuite '
          'comme un encaissement, avec la catégorie « Remboursement d\'écart '
          'de caisse ».';

  String get _exemple => _perte
      ? 'Ex. : cause non retrouvée après vérification'
      : 'Ex. : reconnu par le caissier, retenue convenue';

  @override
  Widget build(BuildContext context) {
    final ecart = widget.ecart;
    final manquant = ecart.estManquant;
    final couleur = manquant ? _kError : _kAmber;
    final date = ecart.dateCloture;
    final accent = _perte ? _kAmber : _kPrimary;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  manquant
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  size: 20,
                  color: couleur),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(manquant ? 'Manquant en caisse' : 'Surplus en caisse',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: couleur)),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.libelleCompte} — '
                      '${date != null ? DateFormat('dd/MM/yyyy').format(date) : 'date inconnue'}',
                      style: const TextStyle(fontSize: 12, color: _kHint),
                    ),
                  ],
                ),
              ),
              Text(
                '${ecart.ecart > 0 ? '+' : ''}${CurrencyFormatter.format(ecart.ecart)}',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: couleur),
              ),
            ],
          ),
          if ((ecart.imputationResponsable ?? '').isNotEmpty ||
              (ecart.motifEcart ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: _kBorder),
            const SizedBox(height: 10),
          ],
          if ((ecart.imputationResponsable ?? '').isNotEmpty)
            _LigneInfo(
                icone: Icons.person_outline_rounded,
                texte: 'Responsable du fonds : ${ecart.imputationResponsable}'),
          if ((ecart.motifEcart ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            _LigneInfo(
                icone: Icons.notes_rounded,
                texte: 'Motif au comptage : ${ecart.motifEcart}'),
          ],
          const SizedBox(height: 12),
          if (widget.occupe)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2)),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _BoutonDecision(
                    label: 'L\'entreprise supporte',
                    accent: _kAmber,
                    selectionne: _decision == 'PERTE',
                    onPressed: widget.gele ? null : () => _choisir('PERTE'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BoutonDecision(
                    label: 'À rembourser',
                    accent: _kPrimary,
                    selectionne: _decision == 'RECOUVREE',
                    onPressed: widget.gele ? null : () => _choisir('RECOUVREE'),
                  ),
                ),
              ],
            ),
            if (_decision != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Text(_explication,
                    style: const TextStyle(
                        fontSize: 12, height: 1.35, color: _kLabel)),
              ),
              const SizedBox(height: 10),
              _LabeledField(
                label: 'Motif de la décision',
                isRequired: true,
                child: TextField(
                  controller: _motifCtrl,
                  maxLines: 2,
                  minLines: 1,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 15, color: _kDark),
                  decoration: _fieldDeco(_exemple),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Le motif est obligatoire côté serveur : le bouton reste
                  // inerte tant qu'il manque, plutôt que d'aller chercher un
                  // refus.
                  onPressed: _motifCtrl.text.trim().isEmpty || widget.gele
                      ? null
                      : () => widget.onImputer(_decision!, _motifCtrl.text.trim()),
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                      _perte ? 'Passer au résultat' : 'Mettre à sa charge',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Choix d'une issue : rempli quand il est retenu, sobre sinon. Deux boutons
/// pleins côte à côte se disputeraient le regard sans dire lequel est choisi.
class _BoutonDecision extends StatelessWidget {
  final String label;
  final Color accent;
  final bool selectionne;
  final VoidCallback? onPressed;

  const _BoutonDecision({
    required this.label,
    required this.accent,
    required this.selectionne,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final forme = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
    const padding = EdgeInsets.symmetric(vertical: 12, horizontal: 6);
    final texte = Text(label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700));

    if (selectionne) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: 16),
        label: texte,
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          padding: padding,
          shape: forme,
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _kDark,
        side: const BorderSide(color: _kBorder),
        padding: padding,
        shape: forme,
      ),
      child: texte,
    );
  }
}

class _LigneInfo extends StatelessWidget {
  final IconData icone;
  final String texte;
  const _LigneInfo({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 14, color: _kHint),
        const SizedBox(width: 7),
        Expanded(
          child: Text(texte,
              style: const TextStyle(
                  fontSize: 12, height: 1.3, color: _kLabel)),
        ),
      ],
    );
  }
}

class _EtatVide extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String texte;
  final Color couleur;

  const _EtatVide({
    required this.icone,
    required this.titre,
    required this.texte,
    required this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icone, size: 28, color: couleur),
          ),
          const SizedBox(height: 14),
          Text(titre,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
          const SizedBox(height: 6),
          Text(texte,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.4, color: _kLabel)),
        ],
      ),
    );
  }
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
