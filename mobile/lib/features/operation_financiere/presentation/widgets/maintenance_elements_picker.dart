import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/catalogue_element_maintenance.dart';
import '../../domain/entities/element_maintenance.dart';
import '../providers/catalogue_element_maintenance_provider.dart';

/// Widget permettant de sélectionner des éléments de maintenance
/// (depuis le catalogue ou en saisie libre) avec leur montant.
class MaintenanceElementsPicker extends ConsumerStatefulWidget {
  final List<ElementMaintenance> elements;
  final ValueChanged<List<ElementMaintenance>> onChanged;

  const MaintenanceElementsPicker({
    super.key,
    required this.elements,
    required this.onChanged,
  });

  @override
  ConsumerState<MaintenanceElementsPicker> createState() =>
      _MaintenanceElementsPickerState();
}

class _MaintenanceElementsPickerState
    extends ConsumerState<MaintenanceElementsPicker> {
  late List<ElementMaintenance> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.elements);
  }

  void _notify() {
    widget.onChanged(List.unmodifiable(_items));
  }

  void _removeAt(int index) {
    setState(() => _items.removeAt(index));
    _notify();
  }

  Future<void> _pickFromCatalogue() async {
    final catalogueAsync =
        ref.read(catalogueElementsMaintenanceProvider);
    final catalogue = catalogueAsync.valueOrNull ?? [];

    if (catalogue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Catalogue vide ou non chargé')));
      return;
    }

    final selected = await showModalBottomSheet<
        List<_CatalogueSelection>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) =>
          _CataloguePickerSheet(catalogue: catalogue),
    );

    if (selected == null || selected.isEmpty) return;

    setState(() {
      for (final s in selected) {
        _items.add(ElementMaintenance(
          catalogueElementId: s.element.id,
          catalogueElementLibelle: s.element.libelle,
          montant: s.montant,
        ));
      }
    });
    _notify();
  }

  Future<void> _addFreeText() async {
    final result = await showDialog<ElementMaintenance>(
      context: context,
      builder: (_) => const _FreeTextDialog(),
    );
    if (result == null) return;
    setState(() => _items.add(result));
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text('Aucun élément ajouté',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          )
        else
          ...List.generate(_items.length, (i) {
            final el = _items[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.build_circle_outlined,
                      size: 18, color: Colors.indigo.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(el.effectiveLibelle,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(
                          '${el.montant.toStringAsFixed(0)} XOF',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.red.shade400,
                    onPressed: () => _removeAt(i),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFromCatalogue,
                icon: const Icon(Icons.list_alt, size: 18),
                label: const Text('Depuis catalogue',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addFreeText,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Saisie libre',
                    style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Sélecteur catalogue ────────────────────────────────────────────────────

class _CatalogueSelection {
  final CatalogueElementMaintenance element;
  double montant;
  _CatalogueSelection(this.element, {this.montant = 0});
}

class _CataloguePickerSheet extends StatefulWidget {
  final List<CatalogueElementMaintenance> catalogue;
  const _CataloguePickerSheet({required this.catalogue});

  @override
  State<_CataloguePickerSheet> createState() => _CataloguePickerSheetState();
}

class _CataloguePickerSheetState extends State<_CataloguePickerSheet> {
  final Map<int, _CatalogueSelection> _selected = {};
  final Map<int, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            const Text('Éléments du catalogue',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: widget.catalogue.length,
                itemBuilder: (_, i) {
                  final el = widget.catalogue[i];
                  final isSelected = _selected.containsKey(el.id);
                  _controllers.putIfAbsent(
                      el.id, () => TextEditingController());

                  return CheckboxListTile(
                    dense: true,
                    value: isSelected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected[el.id] = _CatalogueSelection(el);
                        } else {
                          _selected.remove(el.id);
                        }
                      });
                    },
                    title: Text(el.libelle,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: isSelected
                        ? Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TextField(
                              controller: _controllers[el.id],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Montant (XOF)',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 6),
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (v) {
                                final parsed = double.tryParse(
                                    v.replaceAll(',', '.'));
                                if (parsed != null) {
                                  _selected[el.id]!.montant = parsed;
                                }
                              },
                            ),
                          )
                        : null,
                  );
                },
              ),
            ),
            SafeArea(
              child: FilledButton.icon(
                onPressed: () {
                  final result = _selected.values
                      .where((s) => s.montant > 0)
                      .toList();
                  Navigator.pop(context, result);
                },
                icon: const Icon(Icons.check),
                label: Text('Confirmer (${_selected.length})'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Saisie libre ──────────────────────────────────────────────────────────

class _FreeTextDialog extends StatefulWidget {
  const _FreeTextDialog();

  @override
  State<_FreeTextDialog> createState() => _FreeTextDialogState();
}

class _FreeTextDialogState extends State<_FreeTextDialog> {
  final _libelle = TextEditingController();
  final _montant = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _libelle.dispose();
    _montant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saisie libre'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _libelle,
              decoration: const InputDecoration(
                  labelText: 'Libellé', border: OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _montant,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Montant (XOF)',
                  border: OutlineInputBorder()),
              validator: (v) {
                final d = double.tryParse(v?.replaceAll(',', '.') ?? '');
                if (d == null || d <= 0) return 'Montant invalide';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final montant = double.parse(
                _montant.text.replaceAll(',', '.'));
            Navigator.pop(
              context,
              ElementMaintenance(
                  libelle: _libelle.text.trim(), montant: montant),
            );
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
