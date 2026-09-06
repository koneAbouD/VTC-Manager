import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_header.dart';
import '../../../../core/widgets/confirmation_restauration_dialog.dart';
import '../../../../core/widgets/motif_annulation_dialog.dart';
import '../../domain/entities/maintenance.dart';
import '../../../operation_financiere/domain/entities/element_maintenance.dart';
import '../providers/maintenance_provider.dart';
import '../widgets/terminer_maintenance_dialog.dart';
import '../../../operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../../partenaire/presentation/providers/partenaire_providers.dart';
import '../../../../screens/finance/finance_refresh.dart';
import 'maintenance_form_page.dart';

// ── Palette ───────────────────────────────────────────────────────────────────

const _kAccent  = Color(0xFFE65100);
const _kDark    = Color(0xFF1A1A2E);
const _kBorder  = Color(0xFFE3E6EE);
const _kLabel   = Color(0xFF6B7280);
const _kBg      = Color(0xFFF8F9FB);

// ── Page ──────────────────────────────────────────────────────────────────────

class MaintenanceDetailPage extends ConsumerStatefulWidget {
  final Maintenance maintenance;
  const MaintenanceDetailPage({super.key, required this.maintenance});

  @override
  ConsumerState<MaintenanceDetailPage> createState() =>
      _MaintenanceDetailPageState();
}

class _MaintenanceDetailPageState
    extends ConsumerState<MaintenanceDetailPage> {
  late Maintenance _m;

  @override
  void initState() {
    super.initState();
    _m = widget.maintenance;
    _relire();
  }

  /// L'intervention arrive de la liste, où son drapeau « restaurable » a été
  /// posé selon les arrêtés du moment. Une clôture de caisse prise depuis a pu
  /// fermer la restauration : on relit la fiche au serveur à l'ouverture pour
  /// ne proposer que les actions qu'il accepte encore. Échec silencieux — la
  /// fiche de la liste reste affichée, le serveur tranchera de toute façon.
  Future<void> _relire() async {
    final id = widget.maintenance.id;
    if (id == null) return;
    final result =
        await ref.read(maintenanceRepositoryProvider).getMaintenanceById(id);
    if (!mounted) return;
    result.fold(
      (_) {},
      (fraiche) {
        setState(() => _m = fraiche);
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) =>
      DateFormat('dd MMM yyyy', 'fr_FR').format(d);

  String _fmtMontant(double v) {
    final f = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    return f.format(v);
  }

  Color _couleurStatut(String? s) => switch (s) {
        'TERMINEE'  => const Color(0xFF2E7D32),
        'EN_COURS'  => const Color(0xFF1565C0),
        'ANNULEE'   => const Color(0xFF616161),
        _           => const Color(0xFFE65100),
      };

  String _labelStatut(String? s) => switch (s) {
        'TERMINEE'  => 'Terminée',
        'EN_COURS'  => 'En cours',
        'ANNULEE'   => 'Annulée',
        _           => 'Planifiée',
      };

  /// Icône dérivée du libellé de catégorie retourné par le backend.
  IconData _iconeType(String t) {
    final u = t.toUpperCase();
    if (u.contains('VIDANGE'))     return Icons.oil_barrel_outlined;
    if (u.contains('REVISION'))    return Icons.settings_outlined;
    if (u.contains('REPARATION'))  return Icons.build_outlined;
    if (u.contains('CONTROLE'))    return Icons.fact_check_outlined;
    if (u.contains('PNEUMATIQUE')) return Icons.tire_repair_outlined;
    if (u.contains('FREINAGE'))    return Icons.emergency_outlined;
    if (u.contains('PARALISE') || u.contains('PARALYSIE')) {
      return Icons.car_crash_outlined;
    }
    if (u.contains('TOLERIE') || u.contains('TÔLERIE')) {
      return Icons.car_repair_outlined;
    }
    if (u.contains('PEINTURE'))    return Icons.brush_outlined;
    return Icons.construction_outlined;
  }

  /// Qui a prononcé l'annulation, et quand. Nul si le serveur n'a ni l'un ni
  /// l'autre — les maintenances annulées avant que l'annulation ne soit signée.
  String? _signatureAnnulation() {
    final auteur = _m.annulePar?.isNotEmpty == true ? _m.annulePar : null;
    final date = _m.annuleLe != null
        ? DateFormat('dd MMM yyyy à HH:mm', 'fr_FR').format(_m.annuleLe!)
        : null;
    if (auteur != null && date != null) return 'Par $auteur · le $date';
    if (auteur != null) return 'Par $auteur';
    if (date != null) return 'Annulée le $date';
    return null;
  }

  String _displayType() =>
      (_m.categorieTypeLibelle?.isNotEmpty == true)
          ? _m.categorieTypeLibelle!
          : _m.type;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Row(children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
          ),
        ]),
        backgroundColor:
            error ? const Color(0xFFB71C1C) : const Color(0xFF1B5E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: error ? const Duration(seconds: 4) : const Duration(seconds: 2),
      ));
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => MaintenanceFormPage(initial: _m)),
    );
    if (mounted && result == true) Navigator.pop(context, true);
  }

  Future<void> _complete() async {
    final choix = await showTerminerMaintenanceDialog(
      context,
      titre: 'Terminer la maintenance',
      message: 'Renseignez le coût réel des travaux pour clôturer cette '
          'maintenance.',
      typeLabel: _displayType(),
      partenaireNom: _m.partenaireNom,
      elements: _m.detailMaintenance?.elements ?? const [],
    );
    if (choix == null || !mounted) return;

    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .completeMaintenance(_m.id!, choix.cout,
            aCredit: choix.aCredit, dateEcheance: choix.echeance);

    if (!mounted) return;
    if (error != null) {
      _showToast(error, error: true);
    } else {
      ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
      // Une clôture à crédit vient de créer des dettes : l'échéancier et le
      // passif doivent les refléter sans attendre.
      refreshFinances(ref);
      Navigator.pop(context, true);
    }
  }

  Future<void> _annuler() async {
    // Même popup que l'annulation d'une ligne de recette : le motif est
    // obligatoire, il reste attaché à l'intervention abandonnée.
    final motif = await showMotifAnnulationDialog(
      context,
      titre: 'Annuler la maintenance ?',
      message: 'L\'intervention quittera le programme du véhicule mais restera '
          'à son historique. Indiquez le motif de l\'annulation.',
    );
    if (motif == null || !mounted) return;

    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .annulerMaintenance(_m.id!, motif);

    if (!mounted) return;
    if (error != null) {
      _showToast(error, error: true);
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _restaurer() async {
    final confirme = await showConfirmationRestaurationDialog(
      context,
      titre: 'Restaurer la maintenance ?',
      message: 'Elle repassera en planifiée : l\'intervention sera de nouveau '
          'à faire.',
    );
    if (confirme != true || !mounted) return;

    final error = await ref
        .read(maintenanceNotifierProvider.notifier)
        .restaurerMaintenance(_m.id!);

    if (!mounted) return;
    if (error != null) {
      _showToast(error, error: true);
    } else {
      Navigator.pop(context, true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final statColor = _couleurStatut(_m.statut);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppHeader(
        title: 'Détail maintenance',
        // Une intervention close ne se retouche plus (voir `estModifiable`) :
        // pour reprendre une intervention terminée, on annule la dépense
        // qu'elle a générée — la maintenance repasse en planifiée. Annulée,
        // sa seule issue est de revenir en circulation, et seulement tant
        // qu'aucun arrêté ne couvre sa date.
        action: switch (_m) {
          final m when m.statut == 'ANNULEE' && m.restaurable =>
            AppHeaderAction(onTap: _restaurer, icon: Icons.restore_rounded),
          final m when m.estModifiable =>
            AppHeaderAction(onTap: _edit, icon: Icons.edit_rounded),
          _ => null,
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [

                  // ── Hero ─────────────────────────────────────────────
                  // Type et statut sur une même ligne : le badge est poussé au
                  // bord droit par l'Expanded du titre, tout restant centré
                  // verticalement sur la hauteur de la pastille.
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: statColor.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_iconeType(_m.type),
                              color: statColor, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            _displayType(),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _kDark,
                                letterSpacing: -0.3),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _labelStatut(_m.statut),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: statColor),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Rubriques de l'intervention ───────────────────────
                  // Une seule carte : les rubriques se suivent, séparées par un
                  // filet, au lieu de flotter chacune sur la sienne.
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    // La marge verticale appartient à la carte : les rubriques
                    // n'espacent plus qu'horizontalement, sinon deux d'entre
                    // elles laisseraient un trou là où le filet se trouvait.
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _rubriques(),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Actions ───────────────────────────────────────────
                  // Maintenance planifiée : « Annuler » et « Terminer » sur une
                  // même ligne. En cours : « Annuler » seul.
                  //
                  // Terminée : aucune des deux. Sa complétion a produit une
                  // dépense — ou une dette envers le prestataire — et l'annuler
                  // ici laisserait cette charge au journal sans intervention en
                  // face. La reprise passe par l'annulation de la dépense, qui
                  // rend la maintenance à l'état planifié.
                  if (_m.isPending)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: _annuler,
                              icon: const Icon(Icons.cancel_outlined,
                                  color: Colors.red),
                              label: const Text('Annuler',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Colors.red, width: 1.5),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton.icon(
                              onPressed: _complete,
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded),
                              label: const Text('Terminer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600)),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  // Annulée : rien dans le corps. La remise en circulation,
                  // tant que les livres du mois restent ouverts, est portée
                  // par l'icône de l'en-tête. Branche muette indispensable :
                  // sans elle, une annulée retomberait sur « Annuler ».
                  else if (_m.statut == 'ANNULEE')
                    const SizedBox.shrink()
                  else if (_m.statut != 'TERMINEE')
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _annuler,
                        icon: const Icon(Icons.cancel_outlined,
                            color: Colors.red),
                        label: const Text('Annuler',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  // ── Builders ──────────────────────────────────────────────────────────────

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        child: child,
      );

  /// Les rubriques de la carte unique, dans l'ordre. Les rubriques de simples
  /// couples libellé/valeur n'ont ni titre ni filet : elles se lisent comme une
  /// seule liste continue. Description et Éléments gardent leur en-tête, qui
  /// suffit alors à les détacher de ce qui précède.
  List<Widget> _rubriques() {
    final rubriques = <Widget>[
      _section(rows: [
        _infoRow(Icons.calendar_today_outlined, 'Date prévue',
            _fmtDate(_m.datePrevue)),
        if (_m.dateEffectuee != null)
          _infoRow(Icons.check_circle_outline_rounded, 'Date effectuée',
              _fmtDate(_m.dateEffectuee!)),
        if (_m.dureeHeures != null)
          _infoRow(Icons.timer_outlined, 'Durée', '${_m.dureeHeures} heure(s)'),
        if (_m.categorieTypeLibelle != null)
          _infoRow(Icons.label_outline_rounded, 'Catégorie',
              _m.categorieTypeLibelle!),
      ]),
    ];

    // Sur une intervention abandonnée, la première question est « pourquoi » :
    // la rubrique suit immédiatement le badge « Annulée » du hero.
    if (_m.motifAnnulation != null && _m.motifAnnulation!.isNotEmpty) {
      rubriques.add(_rubrique(children: [
        const SizedBox(height: 6),
        _labelRubrique(Icons.cancel_outlined, 'Motif d\'annulation'),
        const SizedBox(height: 10),
        Text(
          _m.motifAnnulation!,
          style: const TextStyle(fontSize: 14, color: _kDark, height: 1.5),
        ),
        if (_signatureAnnulation() != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 10),
            child: Text(
              _signatureAnnulation()!,
              style: const TextStyle(fontSize: 12, color: _kLabel),
            ),
          ),
      ]));
    }

    if (_m.vehiculeImmatriculation != null || _m.vehiculeId != null) {
      rubriques.add(_section(rows: [
        // L'immatriculation suffit à désigner le véhicule ; repli sur
        // l'identifiant tant qu'elle n'est pas renseignée.
        _infoRow(
            Icons.directions_car_filled_rounded,
            'Véhicule',
            _m.vehiculeImmatriculation?.isNotEmpty == true
                ? _m.vehiculeImmatriculation!
                : 'Véhicule #${_m.vehiculeId}'),
      ]));
    }

    if (_m.partenaireNom != null ||
        _m.kilometrageAuMoment != null ||
        _m.kilometrageProchaine != null) {
      rubriques.add(_section(rows: [
        if (_m.partenaireNom != null)
          _infoRow(Icons.store_outlined, 'Partenaire', _m.partenaireNom!),
        if (_m.kilometrageAuMoment != null)
          _infoRow(Icons.speed_outlined, 'Kilométrage',
              '${_m.kilometrageAuMoment} km'),
        if (_m.kilometrageProchaine != null)
          _infoRow(Icons.arrow_forward_rounded, 'Prochain entretien',
              '${_m.kilometrageProchaine} km'),
      ]));
    }

    if (_m.id != null) rubriques.add(_blocDettes());

    if (_m.description != null && _m.description!.isNotEmpty) {
      rubriques.add(_rubrique(
        children: [
          const SizedBox(height: 6),
          _labelRubrique(Icons.notes_outlined, 'Description'),
          const SizedBox(height: 10),
          Text(
            _m.description!,
            style: const TextStyle(fontSize: 14, color: _kDark, height: 1.5),
          ),
        ],
      ));
    }

    final elements = _m.detailMaintenance?.elements ?? const [];
    if (elements.isNotEmpty) {
      rubriques.add(_rubrique(
        children: [
          const SizedBox(height: 6),
          _labelRubrique(Icons.checklist_rounded, 'Éléments'),
          const SizedBox(height: 10),
          ...elements.map((e) => _elementRow(e)),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _kDark)),
              Text(
                _fmtMontant(elements.fold(0.0, (s, e) => s + e.montant)),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _kAccent),
              ),
            ],
          ),
        ],
      ));
    }

    return rubriques;
  }

  /// Ce que l'intervention a laissé à payer. Silencieux quand elle a été
  /// réglée sur place — la majorité des cas.
  Widget _blocDettes() {
    final dettes = ref.watch(facturesDeMaintenanceProvider(_m.id!));
    return dettes.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (liste) {
        final ouvertes = liste.where((f) => f.restantDu > 0).toList();
        if (ouvertes.isEmpty) return const SizedBox.shrink();
        // Le titre de rubrique ayant disparu, c'est le libellé de la ligne qui
        // porte le sens du montant : sans lui, un chiffre en face d'un nom de
        // partenaire ne dirait pas qu'il reste dû.
        return _section(rows: [
          for (final f in ouvertes)
            _infoRow(
                Icons.schedule_outlined,
                'Reste à payer · ${f.partenaireNom ?? 'Partenaire'}',
                _fmtMontant(f.restantDu)),
        ]);
      },
    );
  }

  /// Une rubrique de la carte : le fond, la bordure, les angles et la marge
  /// verticale appartiennent à la carte ; la rubrique n'apporte que son contenu
  /// et son retrait latéral.
  Widget _rubrique({required List<Widget> children}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  /// Rubrique de couples libellé/valeur : sans en-tête, ses lignes prolongent
  /// celles de la rubrique précédente.
  Widget _section({required List<Widget> rows}) => _rubrique(children: rows);

  /// En-tête de rubrique au style d'une ligne d'info — mêmes icône fine et
  /// libellé discret que « Coût » —, pour une rubrique qui se lit dans la
  /// continuité des couples libellé/valeur.
  Widget _labelRubrique(IconData icon, String label) => Row(children: [
        Icon(icon, size: 15, color: _kLabel),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 13, color: _kLabel)),
      ]);

  Widget _infoRow(IconData icon, String label, String value,
          {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: _kLabel),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: _kLabel)),
            ),
            Expanded(
              flex: 3,
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _kDark),
              ),
            ),
          ],
        ),
      );

  Widget _elementRow(ElementMaintenance e) => Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3EB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kAccent.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          const Icon(Icons.build_circle_outlined, size: 14, color: _kAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.libelleAvecQuantite,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _kDark),
                ),
                // Qui a fourni la ligne : le sien, ou celui de l'intervention.
                // La nuance se lit à la graisse, sans deuxième colonne.
                if (_nomPrestataire(e) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined,
                            size: 11, color: _kLabel),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _nomPrestataire(e)!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11,
                                color: _kLabel,
                                fontWeight: e.partenaireNom != null
                                    ? FontWeight.w600
                                    : FontWeight.w400),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtMontant(e.montant),
            style: const TextStyle(
                fontSize: 12, color: _kAccent, fontWeight: FontWeight.w700),
          ),
        ]),
      );

  /// Prestataire affiché pour une ligne : le sien s'il en a un, sinon celui de
  /// l'intervention. Null quand aucun des deux n'est renseigné.
  String? _nomPrestataire(ElementMaintenance e) =>
      e.partenaireNom ?? _m.partenaireNom;
}
