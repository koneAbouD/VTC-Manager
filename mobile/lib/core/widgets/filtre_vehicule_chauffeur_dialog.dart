import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_state.dart';
import '../../features/vehicule/domain/entities/vehicule.dart';
import '../../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../../features/vehicule/presentation/providers/vehicule_state.dart';

// ── Type résultat ─────────────────────────────────────────────────────────────

typedef FiltreVehiculeChauffeurResult
    = ({Vehicule? vehicule, Chauffeur? chauffeur});

// ── Fonction d'entrée publique ────────────────────────────────────────────────

Future<FiltreVehiculeChauffeurResult?> showFiltreVehiculeChauffeurDialog(
  BuildContext context, {
  Vehicule?  vehiculeInitial,
  Chauffeur? chauffeurInitial,
  bool avecChauffeur = true,
}) {
  return showDialog<FiltreVehiculeChauffeurResult>(
    context: context,
    builder: (_) => _FiltreDialog(
      vehiculeInitial:  vehiculeInitial,
      chauffeurInitial: chauffeurInitial,
      avecChauffeur:    avecChauffeur,
    ),
  );
}

// ── Palette ───────────────────────────────────────────────────────────────────

const _kPrimary   = Color(0xFF1565C0);
const _kFieldFill = Color(0xFFF2F3F5);
const _kHint      = Color(0xFF9AA0AE);
const _kDark      = Color(0xFF1A1A2E);
const _kLabel     = Color(0xFF6B7280);
const _kGreen     = Color(0xFF2E7D32);

InputDecoration _deco(String hint, {IconData? prefix}) => InputDecoration(
      hintText:   hint,
      hintStyle:  const TextStyle(color: _kHint, fontSize: 14),
      filled:     true,
      fillColor:  _kFieldFill,
      prefixIcon: prefix != null ? Icon(prefix, size: 18, color: _kHint) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
    );

// ── Dialog principal ──────────────────────────────────────────────────────────

class _FiltreDialog extends ConsumerStatefulWidget {
  final Vehicule?  vehiculeInitial;
  final Chauffeur? chauffeurInitial;
  final bool       avecChauffeur;

  const _FiltreDialog({
    this.vehiculeInitial,
    this.chauffeurInitial,
    required this.avecChauffeur,
  });

  @override
  ConsumerState<_FiltreDialog> createState() => _FiltreDialogState();
}

class _FiltreDialogState extends ConsumerState<_FiltreDialog> {
  Vehicule?  _vehicule;
  Chauffeur? _chauffeur;

  @override
  void initState() {
    super.initState();
    _vehicule  = widget.vehiculeInitial;
    _chauffeur = widget.chauffeurInitial;
  }

  bool get _hasFilter => _vehicule != null || _chauffeur != null;

  List<Vehicule> get _vehicules {
    final s = ref.watch(vehiculeNotifierProvider);
    return switch (s) {
      VehiculeLoaded(:final vehicules)        => vehicules,
      VehiculeActionSuccess(:final vehicules) => vehicules,
      _ => <Vehicule>[],
    };
  }

  List<Chauffeur> get _chauffeurs {
    final s = ref.watch(chauffeurNotifierProvider);
    return switch (s) {
      ChauffeurLoaded(:final chauffeurs)        => chauffeurs,
      ChauffeurActionSuccess(:final chauffeurs) => chauffeurs,
      _ => <Chauffeur>[],
    };
  }

  static String _vehiculeLabel(Vehicule v) =>
      v.libelle?.isNotEmpty == true ? v.libelle! : '${v.marque} ${v.modele}';

  @override
  Widget build(BuildContext context) {
    final vehicules  = _vehicules;
    final chauffeurs = _chauffeurs;

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ─────────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Filtres avancés',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (_hasFilter)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(
                          () { _vehicule = null; _chauffeur = null; }),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Réinitialiser'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.avecChauffeur
                  ? 'Affiner les résultats par véhicule et/ou chauffeur.'
                  : 'Affiner les résultats par véhicule.',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 18),

            // ── Véhicule ─────────────────────────────────────────────
            const _FieldLabel(
                icon: Icons.directions_car_outlined, label: 'Véhicule'),
            const SizedBox(height: 6),
            Autocomplete<Vehicule>(
              initialValue: TextEditingValue(
                  text: _vehicule != null
                      ? _vehiculeLabel(_vehicule!)
                      : ''),
              displayStringForOption: _vehiculeLabel,
              optionsBuilder: (v) {
                final q = v.text.toLowerCase();
                if (q.isEmpty) return vehicules;
                return vehicules.where((veh) =>
                    _vehiculeLabel(veh).toLowerCase().contains(q) ||
                    veh.immatriculation.toLowerCase().contains(q));
              },
              onSelected: (v) => setState(() => _vehicule = v),
              fieldViewBuilder: (ctx, ctrl, focus, _) => TextFormField(
                controller: ctrl,
                focusNode:  focus,
                style: const TextStyle(fontSize: 14, color: _kDark),
                onChanged: (text) {
                  // Désélectionner si le texte ne correspond plus
                  if (_vehicule != null &&
                      text != _vehiculeLabel(_vehicule!)) {
                    setState(() => _vehicule = null);
                  }
                },
                decoration: _deco('Rechercher un véhicule…',
                        prefix: Icons.search)
                    .copyWith(
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: ctrl,
                    builder: (_, v, __) {
                      if (v.text.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          ctrl.clear();
                          setState(() => _vehicule = null);
                        },
                        child: Icon(
                          _vehicule != null
                              ? Icons.check_circle_outline_rounded
                              : Icons.close,
                          size: 18,
                          color: _vehicule != null ? _kGreen : _kHint,
                        ),
                      );
                    },
                  ),
                ),
              ),
              optionsViewBuilder: (ctx, onSel, opts) =>
                  _DropdownList<Vehicule>(
                options: opts.toList(),
                leadingBuilder: (_) => const CircleAvatar(
                  radius: 15,
                  backgroundColor: Color(0x1A1565C0),
                  child: Icon(Icons.directions_car_outlined,
                      size: 14, color: _kPrimary),
                ),
                titleBuilder:    _vehiculeLabel,
                subtitleBuilder: (v) => v.immatriculation,
                onTap: onSel,
              ),
            ),

            // ── Chauffeur (optionnel) ─────────────────────────────────
            if (widget.avecChauffeur) ...[
              const SizedBox(height: 14),
              const _FieldLabel(
                  icon: Icons.person_outline_rounded, label: 'Chauffeur'),
              const SizedBox(height: 6),
              Autocomplete<Chauffeur>(
                initialValue: TextEditingValue(
                    text: _chauffeur?.displayName ?? ''),
                displayStringForOption: (c) => c.displayName,
                optionsBuilder: (v) {
                  final q = v.text.toLowerCase();
                  if (q.isEmpty) return chauffeurs;
                  return chauffeurs.where((c) =>
                      c.displayName.toLowerCase().contains(q) ||
                      (c.telephone ?? '').contains(q));
                },
                onSelected: (c) => setState(() => _chauffeur = c),
                fieldViewBuilder: (ctx, ctrl, focus, _) => TextFormField(
                  controller: ctrl,
                  focusNode:  focus,
                  style: const TextStyle(fontSize: 14, color: _kDark),
                  onChanged: (text) {
                    if (_chauffeur != null &&
                        text != _chauffeur!.displayName) {
                      setState(() => _chauffeur = null);
                    }
                  },
                  decoration: _deco('Rechercher un chauffeur…',
                          prefix: Icons.search)
                      .copyWith(
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: ctrl,
                      builder: (_, v, __) {
                        if (v.text.isEmpty) return const SizedBox.shrink();
                        return GestureDetector(
                          onTap: () {
                            ctrl.clear();
                            setState(() => _chauffeur = null);
                          },
                          child: Icon(
                            _chauffeur != null
                                ? Icons.check_circle_outline_rounded
                                : Icons.close,
                            size: 18,
                            color: _chauffeur != null ? _kGreen : _kHint,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                optionsViewBuilder: (ctx, onSel, opts) =>
                    _DropdownList<Chauffeur>(
                  options: opts.toList(),
                  leadingBuilder: (c) => CircleAvatar(
                    radius: 15,
                    backgroundColor: _kPrimary.withValues(alpha: 0.10),
                    child: Text(
                      c.prenom.isNotEmpty
                          ? c.prenom[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                  titleBuilder:    (c) => c.displayName,
                  subtitleBuilder: (c) => c.telephone,
                  onTap: onSel,
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Annuler / Appliquer ───────────────────────────────────
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler',
                      style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ),
              ),
              Container(width: 1, height: 24,
                  color: const Color(0xFFE3E6EE)),
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    (vehicule: _vehicule, chauffeur: _chauffeur),
                  ),
                  child: const Text('Appliquer',
                      style: TextStyle(
                          color: _kPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Label de champ ─────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _FieldLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: _kDark),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _kLabel)),
    ]);
  }
}

// ── Liste déroulante générique ─────────────────────────────────────────────────

class _DropdownList<T> extends StatelessWidget {
  final List<T>             options;
  final Widget Function(T)  leadingBuilder;
  final String Function(T)  titleBuilder;
  final String? Function(T) subtitleBuilder;
  final void Function(T)    onTap;

  const _DropdownList({
    required this.options,
    required this.leadingBuilder,
    required this.titleBuilder,
    required this.subtitleBuilder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 6,
        shadowColor: Colors.black12,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 210),
          child: ListView.separated(
            padding:         const EdgeInsets.symmetric(vertical: 4),
            shrinkWrap:      true,
            itemCount:       options.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Colors.grey.shade100),
            itemBuilder: (_, i) {
              final item = options[i];
              final sub  = subtitleBuilder(item);
              return ListTile(
                dense:    true,
                leading:  leadingBuilder(item),
                title:    Text(titleBuilder(item),
                    style: const TextStyle(
                        fontSize:     13,
                        fontWeight:   FontWeight.w600,
                        color:        _kDark)),
                subtitle: sub != null
                    ? Text(sub,
                          style: const TextStyle(
                              fontSize: 11, color: _kHint))
                    : null,
                onTap: () => onTap(item),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Bouton tune réutilisable ──────────────────────────────────────────────────

class TuneFilterButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool          active;
  const TuneFilterButton({super.key, this.onTap, this.active = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.tune_outlined,
                color: active
                    ? const Color(0xFF1565C0)
                    : const Color(0xFF8A8A8E),
                size: 20),
            if (active)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1565C0),
                      shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
