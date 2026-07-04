import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vehicule/data/datasources/referentiel_datasource.dart';
import '../../../vehicule/presentation/providers/referentiel_provider.dart';
import '../providers/etat_parc_provider.dart';

/// Ouvre le sélecteur de filtre (groupe / activité) de l'état de parc.
Future<void> showEtatParcFiltreSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _EtatParcFiltreSheet(),
  );
}

class _EtatParcFiltreSheet extends ConsumerStatefulWidget {
  const _EtatParcFiltreSheet();

  @override
  ConsumerState<_EtatParcFiltreSheet> createState() =>
      _EtatParcFiltreSheetState();
}

class _EtatParcFiltreSheetState extends ConsumerState<_EtatParcFiltreSheet> {
  int? _groupeId;
  String? _groupeNom;
  int? _activiteId;
  String? _activiteNom;

  @override
  void initState() {
    super.initState();
    final f = ref.read(etatParcFiltreProvider);
    _groupeId = f.groupeId;
    _groupeNom = f.groupeNom;
    _activiteId = f.activiteId;
    _activiteNom = f.activiteNom;
  }

  void _appliquer() {
    ref.read(etatParcFiltreProvider.notifier).state = EtatParcFiltre(
      groupeId: _groupeId,
      groupeNom: _groupeNom,
      activiteId: _activiteId,
      activiteNom: _activiteNom,
    );
    Navigator.of(context).pop();
  }

  void _reinitialiser() {
    ref.read(etatParcFiltreProvider.notifier).state = const EtatParcFiltre();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final groupes = ref.watch(groupesProvider);
    final activites = ref.watch(typesActivitesProvider);
    final aUnFiltre = _groupeId != null || _activiteId != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Filtrer l\'état de parc',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 16),
            _RefDropdown(
              label: 'Groupe',
              placeholder: 'Tous',
              items: groupes,
              selectedId: _groupeId,
              onChanged: (item) => setState(() {
                _groupeId = item?.id;
                _groupeNom = item?.nom;
              }),
            ),
            const SizedBox(height: 14),
            _RefDropdown(
              label: 'Activité',
              placeholder: 'Toutes',
              items: activites,
              selectedId: _activiteId,
              onChanged: (item) => setState(() {
                _activiteId = item?.id;
                _activiteNom = item?.nom;
              }),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                if (aUnFiltre)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _reinitialiser,
                      child: const Text('Réinitialiser',
                          style: TextStyle(color: Colors.black54)),
                    ),
                  ),
                if (aUnFiltre) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF43A047),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _appliquer,
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Menu déroulant d'un référentiel (avec option « tout » = valeur nulle).
class _RefDropdown extends StatelessWidget {
  final String label;
  final String placeholder;
  final AsyncValue<List<ReferentielItem>> items;
  final int? selectedId;
  final ValueChanged<ReferentielItem?> onChanged;

  const _RefDropdown({
    required this.label,
    required this.placeholder,
    required this.items,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700)),
        const SizedBox(height: 6),
        items.when(
          loading: () => const _DropdownShell(
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Chargement…',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          error: (_, __) => const _DropdownShell(
            child: Text('Indisponible',
                style: TextStyle(color: Colors.red, fontSize: 13)),
          ),
          data: (list) {
            // Garde-fou : si l'id sélectionné n'existe plus, on retombe sur null.
            final validId =
                list.any((e) => e.id == selectedId) ? selectedId : null;
            return _DropdownShell(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: validId,
                  hint: Text(placeholder,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 14)),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(placeholder,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    for (final item in list)
                      DropdownMenuItem<int?>(
                        value: item.id,
                        child: Text(item.nom,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (id) => onChanged(
                    id == null
                        ? null
                        : list.firstWhere((e) => e.id == id),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DropdownShell extends StatelessWidget {
  final Widget child;
  const _DropdownShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: child,
    );
  }
}
