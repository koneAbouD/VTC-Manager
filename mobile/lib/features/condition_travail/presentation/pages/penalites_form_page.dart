import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../vehicule/domain/entities/vehicule.dart';
import 'condition_travail_models.dart';

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

// ── Providers locaux ──────────────────────────────────────────────────────────

final _penFormSecureStorage =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _penFormApiClient =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_penFormSecureStorage)));

final _penFormSanctionTypesProvider =
    FutureProvider<List<SanctionTypeLocal>>((ref) async {
  final client = ref.watch(_penFormApiClient);
  final data = await client.get('/conditions-travail/sanctions/types');
  return (data as List)
      .map((e) => SanctionTypeLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

const _typesPenaliteOrdered = [
  'RECETTE_NON_VERSEE',
  'HEURE_FIN_SERVICE_PASSE',
  'EXCES_VITESSE',
];

// ── Page ──────────────────────────────────────────────────────────────────────

class PenalitesFormPage extends ConsumerStatefulWidget {
  final Vehicule vehicule;
  final List<PenaliteLocal> initialPenalites;

  const PenalitesFormPage({
    super.key,
    required this.vehicule,
    required this.initialPenalites,
  });

  @override
  ConsumerState<PenalitesFormPage> createState() => _PenalitesFormPageState();
}

class _PenalitesFormPageState extends ConsumerState<PenalitesFormPage> {
  late List<PenaliteGroupLocal> _groups;
  String _selectedType = 'RECETTE_NON_VERSEE';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = {
      for (final g in PenaliteGroupLocal.fromFlat(widget.initialPenalites))
        g.typePenalite: g
    };
    _groups = [
      for (final t in _typesPenaliteOrdered)
        existing[t] ?? PenaliteGroupLocal(typePenalite: t),
    ];
  }

  PenaliteGroupLocal get _currentGroup =>
      _groups.firstWhere((g) => g.typePenalite == _selectedType);

  int get _currentGroupIndex =>
      _groups.indexWhere((g) => g.typePenalite == _selectedType);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: const AppHeader(title: 'Pénalités'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text(
                  'Pénalités',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                ),
                const SizedBox(width: 8),
                Text(
                  '(Optionnel)',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Les sanctions sont appliquées en cas de non-respect\ndes conditions définies.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PenaliteTypeDropdown(
              selected: _selectedType,
              onChanged: (v) => setState(() => _selectedType = v),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                _GroupCard(
                  group: _currentGroup,
                  onAddSanction: () =>
                      _showAddSanctionSheet(_currentGroupIndex),
                  onEditSanction: (si) =>
                      _showEditSanctionSheet(_currentGroupIndex, si),
                  onDeleteSanction: (si) => setState(() {
                    final gi = _currentGroupIndex;
                    final sanctions = [..._groups[gi].sanctions]..removeAt(si);
                    _groups[gi] = _groups[gi].copyWith(sanctions: sanctions);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B5BDB),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Mettre à jour', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSanctionSheet(int groupIndex) async {
    final group = _groups[groupIndex];
    final result = await showModalBottomSheet<PenaliteLocal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SanctionSheet(
        typePenalite: group.typePenalite,
        initial: null,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _groups[groupIndex] = _groups[groupIndex].copyWith(
        sanctions: [..._groups[groupIndex].sanctions, result],
      );
    });
  }

  Future<void> _showEditSanctionSheet(int groupIndex, int sanctionIndex) async {
    final group = _groups[groupIndex];
    final result = await showModalBottomSheet<PenaliteLocal>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SanctionSheet(
        typePenalite: group.typePenalite,
        initial: group.sanctions[sanctionIndex],
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final sanctions = [..._groups[groupIndex].sanctions];
      sanctions[sanctionIndex] = result;
      _groups[groupIndex] = _groups[groupIndex].copyWith(sanctions: sanctions);
    });
  }

  Future<void> _save() async {
    if (widget.vehicule.id == null) return;
    setState(() => _saving = true);
    try {
      final client = ref.read(_penFormApiClient);
      final flat = _groups.expand((g) => g.toFlat()).toList();
      final body = flat.map((p) => p.toJson()).toList();
      await client.put('/vehicules/${widget.vehicule.id}/penalites', body);
      if (!mounted) return;
      _appToast(context, 'Pénalités mises à jour.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _appToast(context, 'Erreur : $e', type: _ToastType.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ── Carte groupe de pénalité ──────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final PenaliteGroupLocal group;
  final VoidCallback onAddSanction;
  final ValueChanged<int> onEditSanction;
  final ValueChanged<int> onDeleteSanction;

  const _GroupCard({
    required this.group,
    required this.onAddSanction,
    required this.onEditSanction,
    required this.onDeleteSanction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Text(
              'Sanctions configurées',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          // Sanctions list
          if (group.sanctions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                'Aucune sanction — ajoutez-en une ci-dessous.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            )
          else
            for (int i = 0; i < group.sanctions.length; i++)
              _SanctionRow(
                penalite: group.sanctions[i],
                onEdit: () => onEditSanction(i),
                onDelete: () => onDeleteSanction(i),
                showDivider: i < group.sanctions.length - 1,
              ),
          const Divider(height: 1, color: Color(0xFFE4E7EC)),
          // Ajouter une sanction
          InkWell(
            onTap: onAddSanction,
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B5BDB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Ajouter une sanction',
                    style: TextStyle(
                      color: Color(0xFF3B5BDB),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne sanction ────────────────────────────────────────────────────────────

class _SanctionRow extends StatelessWidget {
  final PenaliteLocal penalite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDivider;

  const _SanctionRow({
    required this.penalite,
    required this.onEdit,
    required this.onDelete,
    required this.showDivider,
  });

  static String _label(String code) => switch (code) {
        'BUZZER' => 'Buzzer',
        'AMENDE' => 'Amende',
        'MAJORATION' => 'Majoration',
        'IMMOBILISATION' => 'Immobilisation',
        _ => code,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label(penalite.typeSanction),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      penalite.resume,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF3B5BDB), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    color: Color(0xFFD32F2F), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 16, color: Color(0xFFE4E7EC)),
      ],
    );
  }
}

// ── Bouton "Ajouter un type de pénalité" ──────────────────────────────────────

// ── Dropdown sélecteur de type de pénalité ────────────────────────────────────

class _PenaliteTypeDropdown extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PenaliteTypeDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          items: [
            for (final t in _typesPenaliteOrdered)
              DropdownMenuItem(
                value: t,
                child: Text(PenaliteGroupLocal(typePenalite: t).label),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Bottom sheet sanction ──────────────────────────────────────────────────────

class _SanctionSheet extends ConsumerStatefulWidget {
  final String typePenalite;
  final PenaliteLocal? initial;

  const _SanctionSheet({
    required this.typePenalite,
    this.initial,
  });

  @override
  ConsumerState<_SanctionSheet> createState() => _SanctionSheetState();
}

class _SanctionSheetState extends ConsumerState<_SanctionSheet> {
  String? _typeSanction;
  final _valeurCtrl = TextEditingController();
  String? _dureeImmobilisation;

  static const _dureeOptions = {
    '5': '5 minutes',
    '10': '10 minutes',
    '15': '15 minutes',
    '30': '30 minutes',
    '60': '1 heure',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    if (p != null) {
      _typeSanction = p.typeSanction;
      switch (p.typeSanction) {
        case 'BUZZER':
          _valeurCtrl.text = p.dureeSanctionSecondes?.toString() ?? '';
          break;
        case 'AMENDE':
        case 'MAJORATION':
          _valeurCtrl.text = p.montant?.toStringAsFixed(0) ?? '';
          break;
        case 'IMMOBILISATION':
          _dureeImmobilisation = p.dureeImmobilisationMinutes?.toString();
          break;
      }
    }
  }

  @override
  void dispose() {
    _valeurCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncTypes = ref.watch(_penFormSanctionTypesProvider);
    final isEdit = widget.initial != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: asyncTypes.when(
        loading: () => const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => SizedBox(
          height: 160,
          child: Center(child: Text('Erreur : $e')),
        ),
        data: (types) {
          final selectedType =
              types.where((t) => t.code == _typeSanction).firstOrNull;

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Modifier la sanction' : 'Ajouter une sanction',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  'Type de sanction',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _SanctionTypeSelector(
                  types: types,
                  selected: _typeSanction,
                  onSelected: (code) => setState(() {
                    _typeSanction = code;
                    _valeurCtrl.clear();
                    _dureeImmobilisation = null;
                  }),
                ),
                if (selectedType != null) ...[
                  const SizedBox(height: 16),
                  _buildParamField(selectedType),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler',
                            style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: selectedType == null ? null : _submit,
                        child: Text(isEdit ? 'Enregistrer' : 'Ajouter'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildParamField(SanctionTypeLocal type) {
    switch (type.paramType) {
      case 'DUREE_SECONDES':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Durée de l'alarme (secondes)",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valeurCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: "Durée de l'alarme",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        );

      case 'MONTANT':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valeurCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Montant',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                suffixText: 'XOF',
                suffixStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        );

      case 'TAUX':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Taux de majoration',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _valeurCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'Taux',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                suffixText: '%',
                suffixStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ],
        );

      case 'DUREE_MINUTES':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Durée avant arrêt du véhicule',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dureeImmobilisation,
                  isExpanded: true,
                  hint: const Text('Durée avant arrêt'),
                  borderRadius: BorderRadius.circular(12),
                  items: _dureeOptions.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _dureeImmobilisation = v),
                ),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _submit() {
    final type = _typeSanction!;
    PenaliteLocal penalite;
    switch (type) {
      case 'BUZZER':
        penalite = PenaliteLocal(
          id: widget.initial?.id,
          typePenalite: widget.typePenalite,
          typeSanction: type,
          dureeSanctionSecondes: int.tryParse(_valeurCtrl.text) ?? 30,
        );
        break;
      case 'AMENDE':
      case 'MAJORATION':
        penalite = PenaliteLocal(
          id: widget.initial?.id,
          typePenalite: widget.typePenalite,
          typeSanction: type,
          montant: double.tryParse(_valeurCtrl.text) ?? 0,
        );
        break;
      case 'IMMOBILISATION':
        penalite = PenaliteLocal(
          id: widget.initial?.id,
          typePenalite: widget.typePenalite,
          typeSanction: type,
          dureeImmobilisationMinutes:
              int.tryParse(_dureeImmobilisation ?? '') ?? 5,
        );
        break;
      default:
        return;
    }
    Navigator.pop(context, penalite);
  }
}

// ── Sélecteur type de sanction ─────────────────────────────────────────────────

class _SanctionTypeSelector extends StatelessWidget {
  final List<SanctionTypeLocal> types;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _SanctionTypeSelector({
    required this.types,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selected != null
                    ? types
                            .where((t) => t.code == selected)
                            .firstOrNull
                            ?.label ??
                        selected!
                    : 'Type de sanction',
                style: TextStyle(
                  color:
                      selected != null ? Colors.black87 : Colors.grey.shade400,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down,
                color: Colors.grey.shade600, size: 22),
          ],
        ),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in types)
                InkWell(
                  onTap: () {
                    onSelected(t.code);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: selected == t.code
                                  ? const Color(0xFF1565C0)
                                  : Colors.grey.shade400,
                              width: 2,
                            ),
                            color: selected == t.code
                                ? const Color(0xFF1565C0)
                                : Colors.transparent,
                          ),
                          child: selected == t.code
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Text(t.label, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
