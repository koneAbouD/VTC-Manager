import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/encaissement_lot.dart';
import 'app_error_banner.dart';
import 'date_filter_dialogs.dart';
import 'encaissement_ligne_dialog.dart' show ModeEncaissementSaisie;
import 'montant_field.dart';
import 'premium_select_field.dart';

// ── Palette (cohérente avec les autres feuilles d'encaissement) ───────────────

const _kPrimary = Color(0xFF3B5BDB);
const _kGreen = Color(0xFF2E7D32);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint = Color(0xFF9AA0AE);
const _kLabel = Color(0xFF6B7280);
const _kBorder = Color(0xFFE3E6EE);
const _kDark = Color(0xFF1A1A2E);
const _kError = Color(0xFFE03131);

// ── Entrées / sorties ─────────────────────────────────────────────────────────

/// La créance sœur du même jour — la cotisation face à la recette, et
/// inversement. Le chauffeur règle les deux d'un même versement : ce que la
/// ligne principale ne peut pas absorber lui revient.
class JumelleLot {
  final int    id;
  final String libelle;
  final double restant;

  const JumelleLot({
    required this.id,
    required this.libelle,
    required this.restant,
  });
}

/// Une créance retenue dans le lot, telle qu'elle s'affiche au guichet.
class LigneLotEncaissable {
  final int id;
  final String titre;
  final String sousTitre;

  /// Ce que la ligne elle-même peut encore recevoir.
  final double restant;

  /// La créance du même jour, quand il y en a une d'ouverte.
  final JumelleLot? jumelle;

  const LigneLotEncaissable({
    required this.id,
    required this.titre,
    required this.sousTitre,
    required this.restant,
    this.jumelle,
  });

  /// Limite de la saisie : la créance du jour, plus sa sœur s'il y en a une.
  double get plafond => restant + (jumelle?.restant ?? 0);

  /// Comment un montant se répartit entre les deux : la ligne ouverte d'abord,
  /// le surplus pour la sœur.
  ({double principal, double jumelle}) repartir(double montant) {
    final part = montant.clamp(0.0, restant);
    final surplus = (montant - part).clamp(0.0, jumelle?.restant ?? 0.0);
    return (principal: part, jumelle: surplus);
  }
}

/// Ce que la feuille a recueilli : les montants ligne par ligne, et ce qui est
/// commun à tout le versement.
class SaisieLot {
  final List<MontantLigne> lignes;
  final ModeEncaissementSaisie mode;
  final String? reference;
  final DateTime date;
  final String? commentaire;

  const SaisieLot({
    required this.lignes,
    required this.mode,
    required this.reference,
    required this.date,
    required this.commentaire,
  });
}

/// Ce que l'appelant rapporte du serveur.
///
/// Un lot n'est pas un tout ou rien : une période clôturée, une caisse déjà
/// comptée ou un mode de paiement non autorisé ne concernent que leur ligne.
/// [erreurGlobale] est réservée à ce qui a empêché le lot d'être envoyé —
/// réseau coupé, session expirée.
class IssueLot {
  final String? erreurGlobale;
  final Set<int> reussies;
  final Map<int, String> echecs;

  const IssueLot({
    this.erreurGlobale,
    this.reussies = const {},
    this.echecs = const {},
  });

  factory IssueLot.erreur(String message) => IssueLot(erreurGlobale: message);

  factory IssueLot.depuis(ResultatEncaissementLot resultat) => IssueLot(
        reussies: resultat.resultats
            .where((r) => r.succes)
            .map((r) => r.ligneId)
            .toSet(),
        echecs: {
          for (final r in resultat.lignesEnEchec)
            r.ligneId: r.message ?? 'Encaissement refusé.',
        },
      );
}

/// Ouvre la feuille d'encaissement de masse.
///
/// Retourne `true` dès qu'au moins une ligne est passée — la liste appelante
/// doit alors se rafraîchir —, `null` si le guichet a refermé sans rien
/// encaisser.
Future<bool?> showEncaissementLotDialog(
  BuildContext context, {
  required String titre,
  required List<LigneLotEncaissable> lignes,
  required Future<IssueLot> Function(SaisieLot saisie) onEncaisser,
  Color couleur = _kGreen,
  IconData icone = Icons.receipt_long_outlined,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    backgroundColor: const Color(0xFFF8F9FB),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _EncaissementLotSheet(
      titre: titre,
      lignes: lignes,
      couleur: couleur,
      icone: icone,
      onEncaisser: onEncaisser,
    ),
  );
}

// ── Sheet ─────────────────────────────────────────────────────────────────────

class _EncaissementLotSheet extends StatefulWidget {
  final String titre;
  final List<LigneLotEncaissable> lignes;
  final Color couleur;
  final IconData icone;
  final Future<IssueLot> Function(SaisieLot) onEncaisser;

  const _EncaissementLotSheet({
    required this.titre,
    required this.lignes,
    required this.couleur,
    required this.icone,
    required this.onEncaisser,
  });

  @override
  State<_EncaissementLotSheet> createState() => _EncaissementLotSheetState();
}

class _EncaissementLotSheetState extends State<_EncaissementLotSheet> {
  final _formKey = GlobalKey<FormState>();
  final _refCtrl = TextEditingController();
  final _commentCtrl = TextEditingController();

  /// Un contrôleur par ligne : le montant se règle créance par créance, un
  /// chauffeur soldant rarement toutes ses journées au franc près.
  late final Map<int, TextEditingController> _montants;

  ModeEncaissementSaisie _mode = ModeEncaissementSaisie.especes;

  /// Aujourd'hui par défaut, et jamais au-delà : un encaissement constate de
  /// l'argent déjà reçu.
  DateTime _date = DateTime.now();

  bool _submitting = false;
  String? _erreurGlobale;

  /// Lignes déjà encaissées lors d'un envoi précédent : elles quittent la
  /// feuille, il ne faut surtout pas les rejouer.
  final Set<int> _reussies = {};

  /// Motif de refus par ligne, affiché sous la créance concernée.
  final Map<int, String> _echecs = {};

  /// Créances sœurs écartées du versement. Cochées par défaut : le chauffeur
  /// règle le plus souvent la journée entière d'un seul coup.
  final Set<int> _jumellesExclues = {};

  bool _jumelleIncluse(LigneLotEncaissable ligne) =>
      ligne.jumelle != null && !_jumellesExclues.contains(ligne.id);

  double _restantPrincipal(LigneLotEncaissable ligne) =>
      ligne.restant;

  double _restantJumelle(LigneLotEncaissable ligne) =>
      ligne.jumelle?.restant ?? 0;

  /// Ce qu'une ligne peut encore recevoir : sa créance, plus celle du même
  /// jour tant qu'elle est cochée.
  double _plafondDe(LigneLotEncaissable ligne) =>
      _restantPrincipal(ligne) +
      (_jumelleIncluse(ligne) ? _restantJumelle(ligne) : 0);

  /// Où ira le montant saisi, sur les restes du moment.
  ({double principal, double jumelle}) _repartir(
      LigneLotEncaissable ligne, double montant) {
    final part = montant.clamp(0.0, _restantPrincipal(ligne));
    final surplus = (montant - part)
        .clamp(0.0, _jumelleIncluse(ligne) ? _restantJumelle(ligne) : 0.0);
    return (principal: part, jumelle: surplus);
  }

  /// La créance sœur suit le montant, et le montant suit la case : décochée,
  /// elle ramène la saisie au reste de la créance affichée ; recochée, elle la
  /// porte au total de la journée. À l'inverse, un montant qui ne dépasse plus
  /// la créance affichée décoche la sœur — elle ne recevrait rien.
  void _basculerJumelle(LigneLotEncaissable ligne, bool inclure) {
    setState(() {
      if (inclure) {
        _jumellesExclues.remove(ligne.id);
      } else {
        _jumellesExclues.add(ligne.id);
      }
    });
    _montants[ligne.id]?.text = formatMontantSaisie(_plafondDe(ligne));
  }

  void _synchroniserJumelle(LigneLotEncaissable ligne) {
    if (ligne.jumelle == null) return;
    final montant = parseMontant(_montants[ligne.id]!.text) ?? 0;
    // Champ en cours d'effacement : on laisse la case en l'état.
    if (montant <= 0) return;

    if (montant > _restantPrincipal(ligne)) {
      _jumellesExclues.remove(ligne.id);
    } else {
      _jumellesExclues.add(ligne.id);
    }
  }

  @override
  void initState() {
    super.initState();
    // Prérempli sur tout ce que la journée doit — la créance affichée et
    // celle du même jour : le cas courant est un versement qui solde les deux.
    // Le guichet réduit ce qui n'a pas été payé.
    _montants = {
      for (final l in widget.lignes)
        l.id: TextEditingController(text: formatMontantSaisie(l.plafond))
          ..addListener(() => _onMontantChange(l)),
    };
  }

  @override
  void dispose() {
    for (final c in _montants.values) {
      c.dispose();
    }
    _refCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  void _onMontantChange(LigneLotEncaissable ligne) {
    _synchroniserJumelle(ligne);
    if (mounted) setState(() {});
  }

  // ── Lecture de la saisie ───────────────────────────────────────────────────

  List<LigneLotEncaissable> get _lignesRestantes =>
      widget.lignes.where((l) => !_reussies.contains(l.id)).toList();

  double _montantDe(LigneLotEncaissable ligne) =>
      parseMontant(_montants[ligne.id]!.text) ?? 0;

  /// Les créances qui partiront : celles dont le montant est renseigné. Mettre
  /// un montant à zéro est la façon d'écarter une ligne sans quitter la feuille.
  List<LigneLotEncaissable> get _lignesRetenues =>
      _lignesRestantes.where((l) => _montantDe(l) > 0).toList();

  double get _total =>
      _lignesRetenues.fold(0.0, (somme, l) => somme + _montantDe(l));

  bool get _aDesReussites => _reussies.isNotEmpty;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _choisirDate() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(
        initialDate: _date,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = picked;
        _erreurGlobale = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final retenues = _lignesRetenues;
    if (retenues.isEmpty) return;

    setState(() {
      _submitting = true;
      _erreurGlobale = null;
      _echecs.clear();
    });

    final issue = await widget.onEncaisser(SaisieLot(
      lignes: [
        for (final l in retenues)
          MontantLigne(ligneId: l.id, montant: _montantDe(l)),
      ],
      mode: _mode,
      reference: _mode == ModeEncaissementSaisie.mobileMoney &&
              _refCtrl.text.trim().isNotEmpty
          ? _refCtrl.text.trim()
          : null,
      date: _date,
      commentaire:
          _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
    ));

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _erreurGlobale = issue.erreurGlobale;
      _reussies.addAll(issue.reussies);
      _echecs.addAll(issue.echecs);
    });

    // Rien à corriger : la feuille se referme et la liste se rafraîchit.
    if (issue.erreurGlobale == null && _echecs.isEmpty && _aDesReussites) {
      Navigator.pop(context, true);
    }
  }

  void _fermer() => Navigator.pop(context, _aDesReussites ? true : null);

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final fmt =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    final restantes = _lignesRestantes;
    final retenues = _lignesRetenues.length;

    // Retour Android ou glissement vers le bas : la feuille doit rendre le même
    // verdict que le bouton. Sans cela, un lot passé en partie se refermerait
    // sur un « rien à rafraîchir », laissant la liste mentir sur les soldes.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _submitting) return;
        _fermer();
      },
      child: SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardHeight + bottomSafe),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  widget.titre,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _kDark,
                      letterSpacing: -0.4),
                ),
              ),

              // ── Ce qui est déjà passé, quand un envoi n'a réussi qu'en partie ──
              if (_aDesReussites && restantes.isNotEmpty) ...[
                _Bandeau(
                  icone: Icons.check_circle_outline_rounded,
                  couleur: _kGreen,
                  message: '${_reussies.length} ligne(s) encaissée(s). '
                      'Il reste ci-dessous ce qui a été refusé.',
                ),
                const SizedBox(height: 12),
              ],

              // ── Les créances du lot, avec leur montant ────────────────────
              _FormCard(
                icon: widget.icone,
                accent: widget.couleur,
                title: '${restantes.length} ligne(s) sélectionnée(s)',
                child: Column(
                  children: [
                    for (var i = 0; i < restantes.length; i++) ...[
                      if (i > 0)
                        Divider(height: 20, color: Colors.grey.shade100),
                      _LigneLotTile(
                        ligne: restantes[i],
                        controller: _montants[restantes[i].id]!,
                        couleur: widget.couleur,
                        motifEchec: _echecs[restantes[i].id],
                        plafond: _plafondDe(restantes[i]),
                        restantPrincipal: _restantPrincipal(restantes[i]),
                        restantJumelle: _restantJumelle(restantes[i]),
                        jumelleIncluse: _jumelleIncluse(restantes[i]),
                        onJumelleChanged: (v) =>
                            _basculerJumelle(restantes[i], v ?? false),
                        repartition:
                            _repartir(restantes[i], _montantDe(restantes[i])),
                        fmt: fmt,
                        actif: !_submitting,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Total, somme des montants retenus ─────────────────────────
              _TotalCard(
                total: _total,
                lignes: retenues,
                couleur: widget.couleur,
                fmt: fmt,
              ),
              const SizedBox(height: 12),

              // ── Ce qui est commun à tout le versement ─────────────────────
              _FormCard(
                icon: Icons.payments_outlined,
                accent: _kGreen,
                title: 'Versement',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledField(
                      label: 'Mode d\'encaissement',
                      isRequired: true,
                      child: PremiumSelectField<ModeEncaissementSaisie>(
                        value: _mode,
                        isRequired: true,
                        searchable: false,
                        sheetTitle: 'Mode d\'encaissement',
                        options: ModeEncaissementSaisie.values
                            .map((m) => SelectOption<ModeEncaissementSaisie>(
                                value: m, label: m.label))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _mode = v ?? _mode;
                          _erreurGlobale = null;
                        }),
                      ),
                    ),
                    if (_mode == ModeEncaissementSaisie.mobileMoney) ...[
                      const SizedBox(height: 12),
                      _LabeledField(
                        label: 'Référence Mobile Money',
                        child: TextFormField(
                          controller: _refCtrl,
                          style: const TextStyle(fontSize: 15, color: _kDark),
                          decoration: _fieldDeco('N° de transaction'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: 'Date d\'encaissement',
                      child: _DateField(date: _date, onPick: _choisirDate),
                    ),
                    const SizedBox(height: 12),
                    _LabeledField(
                      label: 'Commentaire',
                      child: TextFormField(
                        controller: _commentCtrl,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 15, color: _kDark),
                        decoration: _fieldDeco('Remarques éventuelles…'),
                      ),
                    ),
                  ],
                ),
              ),

              if (_erreurGlobale != null) ...[
                AppErrorBanner(
                  message: _erreurGlobale!,
                  onClose: () => setState(() => _erreurGlobale = null),
                ),
                const SizedBox(height: 10),
              ],

              // ── Boutons ───────────────────────────────────────────────────
              Row(children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _submitting ? null : _fermer,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _kLabel,
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(_aDesReussites ? 'Fermer' : 'Annuler',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed:
                          (_submitting || retenues == 0) ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        _submitting
                            ? 'Encaissement en cours…'
                            : 'Encaisser${retenues > 0 ? ' ($retenues)' : ''}',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade200,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Une créance du lot ────────────────────────────────────────────────────────

class _LigneLotTile extends StatelessWidget {
  final LigneLotEncaissable ligne;
  final TextEditingController controller;
  final Color couleur;
  final String? motifEchec;

  /// Ce que la ligne peut recevoir : sa créance, et celle du même jour tant
  /// que sa case est cochée.
  final double plafond;

  /// Restes du moment, révisions comprises.
  final double restantPrincipal;
  final double restantJumelle;

  /// La créance du même jour entre-t-elle dans le versement ?
  final bool jumelleIncluse;
  final ValueChanged<bool?> onJumelleChanged;

  /// Où ira le montant saisi.
  final ({double principal, double jumelle}) repartition;

  final NumberFormat fmt;
  final bool actif;

  const _LigneLotTile({
    required this.ligne,
    required this.controller,
    required this.couleur,
    required this.motifEchec,
    required this.plafond,
    required this.restantPrincipal,
    required this.restantJumelle,
    required this.jumelleIncluse,
    required this.onJumelleChanged,
    required this.repartition,
    required this.fmt,
    required this.actif,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ligne.titre,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kDark)),
                const SizedBox(height: 2),
                Text(
                    '${ligne.sousTitre} · reste '
                    '${fmt.format(restantPrincipal)}',
                    style: const TextStyle(fontSize: 11, color: _kHint)),
                // La créance du même jour entre dans le versement tant qu'elle
                // est cochée : le chauffeur règle le plus souvent les deux
                // d'un seul coup, mais peut n'en régler qu'une.
                if (ligne.jumelle != null)
                  InkWell(
                    onTap: actif
                        ? () => onJumelleChanged(!jumelleIncluse)
                        : null,
                    child: Row(children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: jumelleIncluse,
                          onChanged: actif ? onJumelleChanged : null,
                          activeColor: couleur,
                          side: const BorderSide(color: _kHint, width: 1.5),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${ligne.jumelle!.libelle} · reste '
                          '${fmt.format(restantJumelle)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: jumelleIncluse ? couleur : _kHint),
                        ),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 132,
            child: MontantField(
              controller: controller,
              enabled: actif,
              // Le reste dû de la créance, jamais plus : au-delà, le serveur
              // refuserait l'écriture.
              plafond: plafond,
              // Vide ou zéro : la ligne est simplement écartée du lot.
              autoriseVide: true,
              // Le champ est étroit : un message court y tient.
              messageDepassement: (max) => 'Max ${formatMontantCourt(max)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _kDark),
              decoration: _fieldDeco('0').copyWith(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
          ),
        ]),
        // Où ira l'argent, dès que le montant déborde sur la ligne sœur : le
        // guichet doit le voir avant d'envoyer.
        if (ligne.jumelle != null && repartition.jumelle > 0) ...[
          const SizedBox(height: 6),
          _Bandeau(
            icone: Icons.alt_route_outlined,
            couleur: couleur,
            message: '${ligne.sousTitre} : '
                '${fmt.format(repartition.principal)} · '
                '${ligne.jumelle!.libelle} : '
                '${fmt.format(repartition.jumelle)}',
          ),
        ],

        if (motifEchec != null) ...[
          const SizedBox(height: 6),
          _Bandeau(
            icone: Icons.error_outline_rounded,
            couleur: _kError,
            message: motifEchec!,
          ),
        ],
      ],
    );
  }

}

// ── Total du lot ──────────────────────────────────────────────────────────────

class _TotalCard extends StatelessWidget {
  final double total;
  final int lignes;
  final Color couleur;
  final NumberFormat fmt;

  const _TotalCard({
    required this.total,
    required this.lignes,
    required this.couleur,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur.withValues(alpha: 0.20)),
      ),
      child: Row(children: [
        Icon(Icons.functions_rounded, size: 16, color: couleur),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Total du versement · $lignes ligne(s)',
              style: const TextStyle(fontSize: 12, color: _kLabel)),
        ),
        Text(fmt.format(total),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: couleur)),
      ]),
    );
  }
}

// ── Bandeau compact ───────────────────────────────────────────────────────────

class _Bandeau extends StatelessWidget {
  final IconData icone;
  final Color couleur;
  final String message;

  const _Bandeau({
    required this.icone,
    required this.couleur,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: couleur.withValues(alpha: 0.22)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 14, color: couleur),
        const SizedBox(width: 7),
        Expanded(
          child: Text(message,
              style: TextStyle(fontSize: 11.5, color: couleur, height: 1.35)),
        ),
      ]),
    );
  }
}

// ── Champ date ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onPick;

  const _DateField({required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final aujourdHui = DateTime.now();
    final estAujourdHui = date.year == aujourdHui.year &&
        date.month == aujourdHui.month &&
        date.day == aujourdHui.day;

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: _kFieldFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: const TextStyle(fontSize: 15, color: _kDark),
            ),
          ),
          if (estAujourdHui)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text("Aujourd'hui",
                  style: TextStyle(fontSize: 12, color: _kHint)),
            ),
          const Icon(Icons.calendar_today_rounded, size: 16, color: _kLabel),
        ]),
      ),
    );
  }
}

// ── Widgets locaux (réplique des autres feuilles) ─────────────────────────────

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
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: _kLabel)),
          if (isRequired) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: _kError, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ]),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

InputDecoration _fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _kHint, fontSize: 15),
      filled: true,
      fillColor: _kFieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kError, width: 1.5),
      ),
    );
