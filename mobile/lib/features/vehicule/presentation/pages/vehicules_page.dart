import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/statut_vehicule.dart';
import '../../domain/entities/vehicule.dart';
import '../providers/referentiel_provider.dart';
import '../providers/vehicule_provider.dart';
import '../providers/vehicule_state.dart';
import 'vehicule_form_page.dart';

// ── Page principale ──────────────────────────────────────────────────────────

class VehiculesPage extends ConsumerStatefulWidget {
  const VehiculesPage({super.key});

  @override
  ConsumerState<VehiculesPage> createState() => _VehiculesPageState();
}

class _VehiculesPageState extends ConsumerState<VehiculesPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  String? _statutFilter;
  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(vehiculeNotifierProvider.notifier).loadVehicules(),
    );
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;
    if (delta > 6 && _headerVisible) {
      setState(() => _headerVisible = false);
    } else if (delta < -6 && !_headerVisible) {
      setState(() => _headerVisible = true);
    }
  }

  List<Vehicule> _filter(List<Vehicule> all) {
    final q = _query.toLowerCase().trim();
    return all.where((v) {
      final matchQuery = q.isEmpty ||
          v.immatriculation.toLowerCase().contains(q) ||
          v.displayName.toLowerCase().contains(q) ||
          (v.groupe?.toLowerCase().contains(q) ?? false);
      final matchStatut =
          _statutFilter == null || v.statut == _statutFilter;
      return matchQuery && matchStatut;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiculeNotifierProvider);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              heightFactor: _headerVisible ? 1.0 : 0.0,
              child: _buildSearchHeader(context),
            ),
          ),
          Expanded(child: _buildBody(state)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VehiculeFormPage()),
          );
          if (mounted) {
            ref.read(vehiculeNotifierProvider.notifier).loadVehicules();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ajouter un véhicule'),
      ),
    );
  }

  Widget _buildSearchHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasFilter = _statutFilter != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // ── Champ de recherche ──────────────────────────────────────
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Immatriculation, modèle, groupe…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _searchCtrl.clear,
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Liste déroulante statut ─────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: hasFilter
                  ? primary.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasFilter ? primary : Colors.grey.shade200,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _statutFilter,
                isDense: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: hasFilter ? primary : Colors.grey.shade500,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasFilter ? primary : Colors.grey.shade700,
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Tous')),
                  for (final s in ref.watch(statutsVehiculeResolvedProvider))
                    DropdownMenuItem(value: s.code, child: Text(s.libelle)),
                ],
                onChanged: (v) => setState(() => _statutFilter = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(VehiculeState state) {
    return switch (state) {
      VehiculeLoading() => const _SkeletonList(),
      VehiculeError(:final message) => _ErrorState(
          message: message,
          onRetry: () =>
              ref.read(vehiculeNotifierProvider.notifier).loadVehicules(),
        ),
      VehiculeLoaded(:final vehicules) ||
      VehiculeActionSuccess(:final vehicules) =>
        _buildList(vehicules),
      _ => const _SkeletonList(),
    };
  }

  Widget _buildList(List<Vehicule> all) {
    final vehicules = _filter(all);
    if (all.isEmpty) {
      return _EmptyState(
        onAdd: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VehiculeFormPage()),
          );
          if (mounted) {
            ref.read(vehiculeNotifierProvider.notifier).loadVehicules();
          }
        },
      );
    }
    if (vehicules.isEmpty) {
      return _NoResultState(
        onClear: () {
          _searchCtrl.clear();
          setState(() {
            _query = '';
            _statutFilter = null;
          });
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            '${vehicules.length} résultat${vehicules.length > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(vehiculeNotifierProvider.notifier).loadVehicules(),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
              itemCount: vehicules.length,
              itemBuilder: (_, i) => _VehiculeCard(vehicule: vehicules[i]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Carte véhicule ───────────────────────────────────────────────────────────

class _VehiculeCard extends ConsumerWidget {
  final Vehicule vehicule;
  const _VehiculeCard({required this.vehicule});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statut = StatutVehicule.resolve(
        vehicule.statut, ref.watch(statutsVehiculeResolvedProvider));
    final statutColor = statut.couleur;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              vehicule.immatriculation,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusChip(
                            label: statut.libelle,
                            color: statutColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        vehicule.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (vehicule.kilometrage != null || vehicule.numeroChassis != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (vehicule.kilometrage != null)
                              _MetaChip(
                                icon: Icons.speed_rounded,
                                label: '${_formatKm(vehicule.kilometrage!)} km',
                                color: Colors.grey.shade700,
                              ),
                            if (vehicule.numeroChassis != null)
                              _MetaChip(
                                icon: Icons.numbers_outlined,
                                label: vehicule.numeroChassis!,
                                color: Colors.grey.shade700,
                              ),
                          ],
                        ),
                      ],
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

  String _formatKm(int km) {
    if (km >= 1000) return '${(km / 1000).toStringAsFixed(0)} k';
    return '$km';
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style:
              TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: 6,
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Bone(w: 110, h: 14, r: 6, opacity: _anim.value),
                        const SizedBox(height: 6),
                        _Bone(w: 150, h: 11, r: 6, opacity: _anim.value),
                        const SizedBox(height: 12),
                        Row(children: [
                          _Bone(w: 70, h: 10, opacity: _anim.value),
                          const SizedBox(width: 10),
                          _Bone(w: 50, h: 10, opacity: _anim.value),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double w, h, r;
  final double opacity;
  const _Bone(
      {required this.w, required this.h, this.r = 6, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: Colors.grey.shade300.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(r),
      ),
    );
  }
}

// ── États vide / erreur / pas de résultat ────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.directions_car_outlined, size: 36, color: color),
            ),
            const SizedBox(height: 20),
            Text('Aucun véhicule',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Ajoutez votre premier véhicule à la flotte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter un véhicule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultState extends StatelessWidget {
  final VoidCallback onClear;
  const _NoResultState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 32, color: Colors.orange.shade400),
            ),
            const SizedBox(height: 16),
            const Text('Aucun résultat',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Essayez un autre terme ou réinitialisez les filtres.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Réinitialiser'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded,
                  size: 32, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text('Erreur de chargement',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
