import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../chauffeur/domain/entities/chauffeur.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import '../../domain/entities/programme_chauffeur.dart';
import '../../domain/entities/programme_travail.dart';
import '../../domain/enums/jour_semaine.dart';
import '../../domain/enums/mode_alternance.dart';
import '../../domain/enums/type_programme_travail.dart';
import '../providers/programme_travail_provider.dart';

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

class ProgrammeTravailFormPage extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  final ProgrammeTravail? initialProgramme;

  const ProgrammeTravailFormPage({
    super.key,
    required this.vehicule,
    this.initialProgramme,
  });

  @override
  ConsumerState<ProgrammeTravailFormPage> createState() =>
      _ProgrammeTravailFormPageState();
}

class _ProgrammeTravailFormPageState
    extends ConsumerState<ProgrammeTravailFormPage> {
  // ── Champs hérités de la condition de travail (non modifiables ici) ────────
  late int _nombreChauffeursAutorises;
  late TypeProgrammeTravail _typeProgramme;
  late TimeOfDay _heureDebutService;
  late TimeOfDay _heureFinService;
  late ModeAlternance _modeAlternance;
  late int? _joursAlternance;
  late DateTime? _dateDebutAlternance;
  late bool _jourSalaireActif;
  JourSemaine? _jourSalaire;

  // ── Champs configurables sur cette page ───────────────────────────────────
  late Set<JourSemaine> _joursAlternanceSemaine;
  late List<ProgrammeChauffeur> _chauffeurs;
  bool _saving = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final p = widget.initialProgramme ??
        ProgrammeTravail.defaultForVehicule(widget.vehicule.id ?? 0);
    _nombreChauffeursAutorises = p.nombreChauffeursAutorises;
    _typeProgramme = p.typeProgramme;
    _heureDebutService = p.heureDebutService;
    _heureFinService = p.heureFinService;
    _modeAlternance = p.modeAlternance;
    _joursAlternance = p.joursAlternance;
    _dateDebutAlternance = p.dateDebutAlternance;
    _jourSalaireActif = p.jourSalaireActif;
    _jourSalaire = p.jourSalaire ?? JourSemaine.dimanche;
    _joursAlternanceSemaine = Set.from(p.joursAlternanceSemaine);
    _chauffeurs = [...p.chauffeursTriesAlternance];
    _renumberOrders();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: const AppHeader(title: 'Programme de travail'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          if (_submitError != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(
              message: _submitError!,
              onClose: () => setState(() => _submitError = null),
            ),
            const SizedBox(height: 8),
          ],
          const Text(
            'Programme\nde travail',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _nombreChauffeursAutorises == 2
                ? 'Configurez les jours de travail et affectez les deux chauffeurs'
                : 'Cliquez sur chauffeur pour configurer le programme de travail',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          if (_nombreChauffeursAutorises > 1) ...[
            _sectionLabel('Jours de travail'),
            const SizedBox(height: 8),
            _joursSemaineField(),
            const SizedBox(height: 24),
          ],
          ..._buildChauffeurCards(),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Enregistrer', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sélecteur jours d'alternance ──────────────────────────────────────────
  Widget _joursSemaineField() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _saving ? null : _openJoursSemaineSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _joursAlternanceSemaine.isEmpty
                  ? Text(
                      'Sélectionner les jours',
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 15),
                    )
                  : Wrap(
                      spacing: 6,
                      children: _joursOrdonnes()
                          .map((j) => _jourCircle(j, selected: true))
                          .toList(),
                    ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: Colors.grey.shade600, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _jourCircle(JourSemaine jour, {required bool selected}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF43A047) : Colors.grey.shade200,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        jour.label.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: selected ? Colors.white : Colors.grey.shade600,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }

  List<JourSemaine> _joursOrdonnes() {
    return JourSemaine.values
        .where((j) => _joursAlternanceSemaine.contains(j))
        .toList();
  }

  Future<void> _openJoursSemaineSheet() async {
    final result = await showModalBottomSheet<Set<JourSemaine>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _JoursSemaineSheet(
        initialSelection: Set.from(_joursAlternanceSemaine),
      ),
    );
    if (result != null) {
      setState(() => _joursAlternanceSemaine = result);
    }
  }

  // ── Cards chauffeurs ──────────────────────────────────────────────────────
  List<Widget> _buildChauffeurCards() {
    final cards = <Widget>[];
    for (int slot = 1; slot <= _nombreChauffeursAutorises; slot++) {
      final pc = _chauffeurs.length >= slot ? _chauffeurs[slot - 1] : null;
      cards.add(_ChauffeurSlotCard(
        slotIndex: slot,
        programmeChauffeur: pc,
        showAlternanceSwitch: _modeAlternance == ModeAlternance.automatique &&
            _nombreChauffeursAutorises > 1,
        saving: _saving,
        onAdd: pc == null ? () => _addChauffeur(slot) : null,
        onRemove: pc != null ? () => _removeChauffeur(pc) : null,
        onDateTap: pc != null && !_saving ? () => _pickDateService(pc) : null,
        onAlternanceChanged: pc != null && !_saving
            ? (value) => _setPremierAlternance(pc, value)
            : null,
      ));
      if (slot < _nombreChauffeursAutorises) {
        cards.add(const SizedBox(height: 12));
      }
    }
    return cards;
  }

  // ── Actions chauffeurs ────────────────────────────────────────────────────
  Future<void> _addChauffeur(int slot) async {
    final chauffeur = await showModalBottomSheet<Chauffeur>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ChauffeurSelectionSheet(
        selectedIds: _chauffeurs.map((pc) => pc.chauffeurId).toSet(),
      ),
    );
    if (chauffeur == null || !mounted) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ConfirmChauffeurSheet(chauffeur: chauffeur),
    );
    if (confirmed != true) return;

    setState(() {
      _chauffeurs = [
        ..._chauffeurs,
        ProgrammeChauffeur(
          chauffeur: chauffeur,
          ordreAlternance: slot,
          ordreJourSalaire: _jourSalaireActif ? slot : null,
          dateService: DateTime.now(),
        ),
      ];
      _renumberOrders();
    });
  }

  Future<void> _removeChauffeur(ProgrammeChauffeur pc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Retirer le chauffeur'),
        content: Text(
            'Voulez-vous retirer ${pc.nomComplet} de ce programme de travail ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _chauffeurs = _chauffeurs
          .where((item) => item.chauffeurId != pc.chauffeurId)
          .toList();
      _renumberOrders();
    });
  }

  void _setPremierAlternance(ProgrammeChauffeur pc, bool enabled) {
    if (_chauffeurs.isEmpty) return;
    final ordered = [..._chauffeurs]
      ..sort((a, b) => a.ordreAlternance.compareTo(b.ordreAlternance));
    final index =
        ordered.indexWhere((item) => item.chauffeurId == pc.chauffeurId);
    if (index < 0) return;
    setState(() {
      final selected = ordered.removeAt(index);
      if (enabled) {
        ordered.insert(0, selected);
      } else {
        ordered.add(selected);
      }
      _chauffeurs = ordered;
      _renumberOrders();
    });
  }

  Future<void> _pickDateService(ProgrammeChauffeur pc) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: pc.dateService ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5),
      locale: const Locale('fr'),
    );
    if (picked == null) return;

    setState(() {
      _chauffeurs = _chauffeurs
          .map(
            (item) => item.chauffeurId == pc.chauffeurId
                ? item.copyWith(dateService: picked)
                : item,
          )
          .toList();
    });
  }

  void _renumberOrders({bool keepSalary = false}) {
    _chauffeurs = [..._chauffeurs]
      ..sort((a, b) => a.ordreAlternance.compareTo(b.ordreAlternance));
    _chauffeurs = _chauffeurs
        .asMap()
        .entries
        .map((entry) => entry.value.copyWith(
              ordreAlternance: entry.key + 1,
              ordreJourSalaire: keepSalary
                  ? entry.value.ordreJourSalaire
                  : (_jourSalaireActif
                      ? (entry.value.ordreJourSalaire ?? entry.key + 1)
                      : null),
            ))
        .toList();
  }

  // ── Sauvegarde ────────────────────────────────────────────────────────────
  Future<void> _save({bool force = false}) async {
    setState(() => _submitError = null);
    if (widget.vehicule.id == null) {
      _showError(
          'Le véhicule doit être enregistré avant de configurer le programme.');
      return;
    }
    if (_nombreChauffeursAutorises == 2 && _chauffeurs.length < 2) {
      _showError(
          'Vous devez affecter exactement 2 chauffeurs lorsque le nombre autorisé est 2.');
      return;
    }
    if (_nombreChauffeursAutorises > 1 && _joursAlternanceSemaine.isEmpty) {
      _showError(
          'Veuillez sélectionner les jours de travail pour les deux chauffeurs.');
      return;
    }
    if (_chauffeurs.any((pc) => pc.dateService == null)) {
      _showError(
          'Veuillez définir la date de prise de service pour chaque chauffeur.');
      return;
    }

    setState(() => _saving = true);

    final programme = ProgrammeTravail(
      id: widget.initialProgramme?.id,
      vehiculeId: widget.vehicule.id!,
      nombreChauffeursAutorises: _nombreChauffeursAutorises,
      typeProgramme: _typeProgramme,
      heureDebutService: _heureDebutService,
      heureFinService: _heureFinService,
      modeAlternance: _modeAlternance,
      joursAlternance: _joursAlternance,
      dateDebutAlternance: _dateDebutAlternance,
      joursAlternanceSemaine: _joursAlternanceSemaine,
      jourSalaireActif: _jourSalaireActif,
      jourSalaire: _jourSalaireActif ? _jourSalaire : null,
      chauffeurs: _chauffeurs,
    );

    final result = await ref
        .read(programmeTravailControllerProvider)
        .saveProgramme(widget.vehicule.id!, programme, force: force);

    if (!mounted) return;
    setState(() => _saving = false);

    if (result == null) {
      _appToast(context, 'Programme enregistré.');
      Navigator.pop(context);
      return;
    }

    if (result is ChauffeurConflictFailure) {
      final confirmed = await _showTransferDialog(result);
      if (confirmed == true && mounted) {
        await _save(force: true);
      }
      return;
    }

    _showError(result as String);
  }

  Future<bool?> _showTransferDialog(ChauffeurConflictFailure conflict) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('Transfert de chauffeur'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                children: [
                  TextSpan(
                    text: conflict.chauffeurNom,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' est actuellement affecté au véhicule '),
                  TextSpan(
                    text: conflict.vehiculeActuelImmatriculation,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text: '.\n\nConfirmez-vous le transfert vers ce véhicule ?'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF43A047)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer le transfert'),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  void _showError(String message) {
    setState(() => _submitError = message);
    _appToast(context, message, type: _ToastType.error);
  }
}

// ── Card slot chauffeur ───────────────────────────────────────────────────────

class _ChauffeurSlotCard extends StatelessWidget {
  final int slotIndex;
  final ProgrammeChauffeur? programmeChauffeur;
  final bool showAlternanceSwitch;
  final bool saving;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onDateTap;
  final ValueChanged<bool>? onAlternanceChanged;

  const _ChauffeurSlotCard({
    required this.slotIndex,
    required this.programmeChauffeur,
    required this.showAlternanceSwitch,
    required this.saving,
    this.onAdd,
    this.onRemove,
    this.onDateTap,
    this.onAlternanceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pc = programmeChauffeur;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chauffeur $slotIndex',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 12),
          if (pc == null)
            InkWell(
              onTap: saving ? null : onAdd,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ajouter un chauffeur (Facultatif)',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            )
          else ...[
            _chauffeurInfo(pc),
            const SizedBox(height: 10),
            _dateServiceTile(pc),
            if (showAlternanceSwitch) ...[
              const SizedBox(height: 10),
              _switchRow(
                label: 'Attribuer la première alternance ?',
                value: pc.ordreAlternance == 1,
                onChanged: onAlternanceChanged,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _dateServiceTile(ProgrammeChauffeur pc) {
    final date = pc.dateService;
    final label = date == null
        ? 'Définir la date de prise de service'
        : DateFormat('dd/MM/yyyy').format(date);

    return InkWell(
      onTap: saving ? null : onDateTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E7EC)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 18,
              color: Color(0xFF43A047),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prise de service',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: date == null
                          ? Colors.grey.shade500
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget _chauffeurInfo(ProgrammeChauffeur pc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE8F5E9),
            child: Text(
              _initials(pc.nomComplet),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF43A047),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pc.nomComplet,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 15))),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF43A047),
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade200,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'CH';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

// ── Bottom sheet sélection jours d'alternance ─────────────────────────────────

class _JoursSemaineSheet extends StatefulWidget {
  final Set<JourSemaine> initialSelection;

  const _JoursSemaineSheet({required this.initialSelection});

  @override
  State<_JoursSemaineSheet> createState() => _JoursSemaineSheetState();
}

class _JoursSemaineSheetState extends State<_JoursSemaineSheet> {
  late Set<JourSemaine> _selection;

  @override
  void initState() {
    super.initState();
    _selection = Set.from(widget.initialSelection);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Jours de travail',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 6),
            Text(
              'Sélectionnez les jours travaillés par les deux chauffeurs',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...JourSemaine.values.map((jour) => _jourTile(jour)),
            _jourTileAll(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _selection),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Valider', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jourTile(JourSemaine jour) {
    final selected = _selection.contains(jour);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selection.remove(jour);
        } else {
          _selection.add(jour);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            jour.label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
              color: selected ? const Color(0xFF43A047) : Colors.black87,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _jourTileAll() {
    final allSelected = _selection.length == JourSemaine.values.length;
    return GestureDetector(
      onTap: () => setState(() {
        if (allSelected) {
          _selection.clear();
        } else {
          _selection = Set.from(JourSemaine.values);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:
              allSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            'Tous les jours',
            style: TextStyle(
              fontWeight: allSelected ? FontWeight.w700 : FontWeight.normal,
              color: allSelected ? const Color(0xFF43A047) : Colors.black87,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sélection chauffeur ───────────────────────────────────────────────────────

class _ChauffeurSelectionSheet extends ConsumerStatefulWidget {
  final Set<int> selectedIds;

  const _ChauffeurSelectionSheet({required this.selectedIds});

  @override
  ConsumerState<_ChauffeurSelectionSheet> createState() =>
      _ChauffeurSelectionSheetState();
}

class _ChauffeurSelectionSheetState
    extends ConsumerState<_ChauffeurSelectionSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncChauffeurs = ref.watch(activeChauffeursProvider);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sélectionnez un chauffeur',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher un chauffeur',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF2F4F8),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFF59E0B), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Seuls les chauffeurs actifs sont visibles dans cette liste.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            asyncChauffeurs.when(
              loading: () => const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SizedBox(
                height: 160,
                child: Center(child: Text('Erreur : $error')),
              ),
              data: (chauffeurs) {
                final disponibles = chauffeurs
                    .where((c) => !widget.selectedIds.contains(c.id))
                    .where((c) =>
                        _query.isEmpty ||
                        c.fullName.toLowerCase().contains(_query) ||
                        (c.telephone ?? '').contains(_query))
                    .toList();

                if (disponibles.isEmpty) {
                  return const SizedBox(
                    height: 120,
                    child: Center(
                        child: Text('Aucun chauffeur actif disponible.')),
                  );
                }

                return Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: disponibles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final chauffeur = disponibles[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, chauffeur),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _initials(chauffeur.fullName),
                                  style: const TextStyle(
                                    color: Color(0xFF43A047),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chauffeur.fullName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(chauffeur.telephone ?? '',
                                        style: TextStyle(
                                            color: Colors.grey.shade700)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  chauffeur.type?.label ?? 'Principal',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF43A047),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'CH';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

// ── Confirmation chauffeur ────────────────────────────────────────────────────

class _ConfirmChauffeurSheet extends StatelessWidget {
  final Chauffeur chauffeur;

  const _ConfirmChauffeurSheet({required this.chauffeur});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirmez le chauffeur',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      _initials(chauffeur.fullName),
                      style: const TextStyle(
                        color: Color(0xFF43A047),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chauffeur.fullName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(chauffeur.telephone ?? '',
                            style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chauffeur.type?.label ?? 'Principal',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF43A047),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Valider', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'CH';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
