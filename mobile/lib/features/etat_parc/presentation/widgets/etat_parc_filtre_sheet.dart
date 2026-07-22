import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/premium_select_field.dart';
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

  bool _refRafraichi = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rafraîchit une seule fois les activités/groupes (édités ailleurs, ex.
    // ReferentielListePage). Ici et non dans initState : `ref.invalidate`
    // dépend du ProviderScope, indisponible pendant initState.
    if (!_refRafraichi) {
      _refRafraichi = true;
      ref.invalidate(typesActivitesProvider);
      ref.invalidate(groupesProvider);
    }
  }

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
            const SizedBox(height: 18),
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
          loading: () => const _DropdownSquelette(texte: 'Chargement…'),
          error: (_, __) =>
              const _DropdownSquelette(texte: 'Indisponible', erreur: true),
          data: (list) {
            // Garde-fou : si l'id sélectionné n'existe plus, on retombe sur null.
            final validId =
                list.any((e) => e.id == selectedId) ? selectedId : null;
            return PremiumSelectField<int>(
              value: validId,
              hint: placeholder,
              sheetTitle: label,
              searchable: false,
              options: list
                  .map((item) =>
                      SelectOption<int>(value: item.id, label: item.nom))
                  .toList(),
              onChanged: (id) => onChanged(
                id == null ? null : list.firstWhere((e) => e.id == id),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Placeholder (chargement / erreur) au même gabarit que le champ premium.
class _DropdownSquelette extends StatelessWidget {
  final String texte;
  final bool erreur;
  const _DropdownSquelette({required this.texte, this.erreur = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (!erreur) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          Text(texte,
              style: TextStyle(
                  color: erreur ? Colors.red : Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
