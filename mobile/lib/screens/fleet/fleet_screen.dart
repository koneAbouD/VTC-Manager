import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_config.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/utils/csv_downloader.dart';
import '../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../features/chauffeur/domain/enums/chauffeur_status.dart';
import '../../features/chauffeur/domain/enums/type_chauffeur.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_state.dart';
import '../../features/chauffeur/presentation/pages/chauffeur_detail_page.dart';
import '../../features/chauffeur/presentation/pages/chauffeur_form_page.dart';
import '../../features/etat_parc/presentation/widgets/etat_parc_tab.dart';
import '../../features/vehicule/domain/entities/statut_vehicule.dart';
import '../../features/vehicule/domain/entities/vehicule.dart';
import '../../features/vehicule/presentation/vehicule_couleurs.dart';
import '../../features/vehicule/presentation/providers/referentiel_provider.dart';
import '../../features/vehicule/presentation/providers/vehicule_provider.dart';
import '../../features/vehicule/presentation/providers/vehicule_state.dart';
import '../../features/vehicule/presentation/pages/vehicule_form_page.dart';
import '../../features/vehicule/presentation/pages/vehicule_detail_page.dart';
import 'fleet_csv.dart';

// ── Bouton d'export CSV (barre de recherche des onglets Véhicules/Chauffeurs) ─

class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        width: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Icon(Icons.file_download_outlined,
            size: 20, color: Colors.grey.shade600),
      ),
    );
  }
}

// Feedback commun après un export CSV depuis un onglet de la flotte.
void _showFleetExportSnack(BuildContext context, String message,
    {String? path}) {
  final detail = path != null ? '\n$path' : '';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('$message$detail')),
      ]),
      duration: const Duration(seconds: 4),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ── Helpers couleur statut ───────────────────────────────────────────────────

Color _cStatutColor(ChauffeurStatus? s) => switch (s) {
      ChauffeurStatus.actif => const Color(0xFF2E7D32),
      ChauffeurStatus.enService => const Color(0xFF1565C0),
      ChauffeurStatus.inactif => Colors.grey,
      ChauffeurStatus.enConge => const Color(0xFFE65100),
      ChauffeurStatus.suspendu => const Color(0xFFC62828),
      null => Colors.grey,
    };

const _avatarPalette = [
  Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFF6A1B9A),
  Color(0xFFAD1457), Color(0xFF00695C), Color(0xFFE65100),
  Color(0xFF37474F), Color(0xFF4527A0),
];
Color _avatarColor(String name) => _avatarPalette[
    name.codeUnits.fold(0, (a, b) => a + b) % _avatarPalette.length];

// ── Écran principal ──────────────────────────────────────────────────────────

class FleetScreen extends ConsumerStatefulWidget {
  const FleetScreen({super.key});

  @override
  ConsumerState<FleetScreen> createState() => _FleetScreenState();
}

class _FleetScreenState extends ConsumerState<FleetScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehiculeState = ref.watch(vehiculeNotifierProvider);
    final chauffeurState = ref.watch(chauffeurNotifierProvider);

    final vCount = switch (vehiculeState) {
      VehiculeLoaded(:final vehicules) => vehicules.length,
      VehiculeActionSuccess(:final vehicules) => vehicules.length,
      _ => 0,
    };
    final cCount = switch (chauffeurState) {
      ChauffeurLoaded(:final chauffeurs) => chauffeurs.length,
      ChauffeurActionSuccess(:final chauffeurs) => chauffeurs.length,
      _ => 0,
    };

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: const Color(0xFF43A047),
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              const Tab(text: 'État de parc'),
              Tab(text: 'Véhicules ($vCount)'),
              Tab(text: 'Chauffeurs ($cCount)'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              const EtatParcTab(),
              _VehiculeTab(),
              _ChauffeurTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Tab Véhicules ────────────────────────────────────────────────────────────

class _VehiculeTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_VehiculeTab> createState() => _VehiculeTabState();
}

class _VehiculeTabState extends ConsumerState<_VehiculeTab> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  String? _statutFilter;
  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
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
      final matchStatut = _statutFilter == null || v.statut == _statutFilter;
      return matchQuery && matchStatut;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vehiculeNotifierProvider);
    return Column(
      children: [
        ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            heightFactor: _headerVisible ? 1.0 : 0.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _headerVisible ? 1.0 : 0.0,
              child: _buildSearchHeader(context),
            ),
          ),
        ),
        Expanded(child: _buildList(state)),
      ],
    );
  }

  Future<void> _exportCsv() async {
    final all = switch (ref.read(vehiculeNotifierProvider)) {
      VehiculeLoaded(:final vehicules) => vehicules,
      VehiculeActionSuccess(:final vehicules) => vehicules,
      _ => <Vehicule>[],
    };
    final vehicules = _filter(all);
    final path = await downloadCsvFile(vehiculesToCsv(vehicules), 'vehicules.csv');
    if (!mounted) return;
    _showFleetExportSnack(
        context, '${vehicules.length} véhicule(s) exporté(s)', path: path);
  }

  Widget _buildSearchHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasFilter = _statutFilter != null;
    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Filtre par statut (à gauche) ─────────────────────────────
          SizedBox(
            height: 46,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasFilter
                    ? primary.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFilter
                      ? primary.withValues(alpha: 0.6)
                      : Colors.grey.shade200,
                  width: hasFilter ? 1.5 : 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: _statutFilter,
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color:
                        hasFilter ? primary : Colors.grey.shade400,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  menuMaxHeight: 280,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasFilter
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color:
                        hasFilter ? primary : Colors.grey.shade600,
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous')),
                    for (final s in ref.watch(statutsVehiculeResolvedProvider))
                      DropdownMenuItem(value: s.code, child: Text(s.libelle)),
                  ],
                  onChanged: (v) {
                    setState(() => _statutFilter = v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Barre de recherche (au centre) ───────────────────────────
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: InputDecoration(
                  hintText: 'Immatriculation, modèle…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _query.isNotEmpty
                        ? primary
                        : Colors.grey.shade400,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 16, color: Colors.grey.shade400),
                          onPressed: _searchCtrl.clear,
                          splashRadius: 16,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Bouton d'export (à droite) ───────────────────────────────
          _ExportButton(onTap: _exportCsv),
        ],
      ),
    );
  }

  Widget _buildList(VehiculeState state) {
    if (state is VehiculeLoading) return const _SkeletonVList();
    if (state is VehiculeError) {
      return _ErrorState(
        message: state.message,
        onRetry: () =>
            ref.read(vehiculeNotifierProvider.notifier).loadVehicules(),
      );
    }

    final all = switch (state) {
      VehiculeLoaded(:final vehicules) => vehicules,
      VehiculeActionSuccess(:final vehicules) => vehicules,
      _ => <Vehicule>[],
    };

    if (all.isEmpty) {
      return _EmptyState(
        icon: Icons.directions_car_outlined,
        title: 'Aucun véhicule',
        subtitle: 'Ajoutez votre premier véhicule à la flotte.',
        actionLabel: 'Ajouter un véhicule',
        onAction: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const VehiculeFormPage())),
      );
    }

    final vehicules = _filter(all);
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

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(vehiculeNotifierProvider.notifier).loadVehicules(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
        itemCount: vehicules.length,
        itemBuilder: (_, i) => _VehiculeCard(
          vehicule: vehicules[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VehiculeDetailPage(vehiculeId: vehicules[i].id!),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Carte véhicule ───────────────────────────────────────────────────────────

class _VehiculeCard extends ConsumerWidget {
  final Vehicule vehicule;
  final VoidCallback onTap;

  const _VehiculeCard({
    required this.vehicule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statut = StatutVehicule.resolve(
        vehicule.statut, ref.watch(statutsVehiculeResolvedProvider));
    final sc = statut.couleur;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                // Pastille icône voiture, teintée de la couleur du véhicule
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 0, 13),
                  child: _VehiculeCouleurIcon(couleur: vehicule.couleur),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
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
                              color: sc,
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

// ── Pastille icône voiture colorée ────────────────────────────────────────────

class _VehiculeCouleurIcon extends StatelessWidget {
  final String? couleur;
  const _VehiculeCouleurIcon({required this.couleur});

  @override
  Widget build(BuildContext context) {
    final color = couleurVehicule(couleur);
    final estClaire = couleurVehiculeEstClaire(color);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: estClaire ? 1 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: estClaire ? const Color(0xFFDDE1EA) : color.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.directions_car_rounded,
        size: 22,
        color: estClaire ? const Color(0xFF6B7280) : color,
      ),
    );
  }
}

// ── Tab Chauffeurs ───────────────────────────────────────────────────────────

class _ChauffeurTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ChauffeurTab> createState() => _ChauffeurTabState();
}

class _ChauffeurTabState extends ConsumerState<_ChauffeurTab> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  ChauffeurStatus? _statutFilter;
  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text);
    });
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

  List<Chauffeur> _filter(List<Chauffeur> all) {
    final q = _query.toLowerCase().trim();
    return all.where((c) {
      final matchQuery = q.isEmpty ||
          c.displayName.toLowerCase().contains(q) ||
          (c.telephone?.contains(q) ?? false) ||
          (c.vehiculeNom?.toLowerCase().contains(q) ?? false);
      final matchStatut =
          _statutFilter == null || c.statut == _statutFilter;
      return matchQuery && matchStatut;
    }).toList();
  }

  Future<void> _confirmDelete(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le chauffeur'),
        content: Text('Supprimer $name définitivement ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await ref
        .read(chauffeurNotifierProvider.notifier)
        .deleteChauffeur(id);
    if (mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chauffeurNotifierProvider);
    return Column(
      children: [
        ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            heightFactor: _headerVisible ? 1.0 : 0.0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _headerVisible ? 1.0 : 0.0,
              child: _buildSearchHeader(context),
            ),
          ),
        ),
        Expanded(child: _buildList(state)),
      ],
    );
  }

  Future<void> _exportCsv() async {
    final all = switch (ref.read(chauffeurNotifierProvider)) {
      ChauffeurLoaded(:final chauffeurs) => chauffeurs,
      ChauffeurActionSuccess(:final chauffeurs) => chauffeurs,
      _ => <Chauffeur>[],
    };
    final chauffeurs = _filter(all);
    final path =
        await downloadCsvFile(chauffeursToCsv(chauffeurs), 'chauffeurs.csv');
    if (!mounted) return;
    _showFleetExportSnack(
        context, '${chauffeurs.length} chauffeur(s) exporté(s)', path: path);
  }

  Widget _buildSearchHeader(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasFilter = _statutFilter != null;
    return Container(
      color: const Color(0xFFF5F6FA),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Filtre par statut (à gauche) ─────────────────────────────
          SizedBox(
            height: 46,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasFilter
                    ? primary.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasFilter
                      ? primary.withValues(alpha: 0.6)
                      : Colors.grey.shade200,
                  width: hasFilter ? 1.5 : 1,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ChauffeurStatus?>(
                  value: _statutFilter,
                  isDense: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color:
                        hasFilter ? primary : Colors.grey.shade400,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  menuMaxHeight: 280,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: hasFilter
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color:
                        hasFilter ? primary : Colors.grey.shade600,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(
                        value: ChauffeurStatus.actif,
                        child: Text('Actif')),
                    DropdownMenuItem(
                        value: ChauffeurStatus.enConge,
                        child: Text('En congé')),
                    DropdownMenuItem(
                        value: ChauffeurStatus.suspendu,
                        child: Text('Suspendu')),
                    DropdownMenuItem(
                        value: ChauffeurStatus.inactif,
                        child: Text('Inactif')),
                  ],
                  onChanged: (v) {
                    setState(() => _statutFilter = v);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Barre de recherche (au centre) ───────────────────────────
          Expanded(
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF1A1A2E)),
                decoration: InputDecoration(
                  hintText: 'Nom, téléphone…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _query.isNotEmpty
                        ? primary
                        : Colors.grey.shade400,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 16, color: Colors.grey.shade400),
                          onPressed: _searchCtrl.clear,
                          splashRadius: 16,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primary, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Bouton d'export (à droite) ───────────────────────────────
          _ExportButton(onTap: _exportCsv),
        ],
      ),
    );
  }

  Widget _buildList(ChauffeurState state) {
    if (state is ChauffeurLoading) return const _SkeletonCList();
    if (state is ChauffeurError) {
      return _ErrorState(
        message: state.message,
        onRetry: () =>
            ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs(),
      );
    }

    final all = switch (state) {
      ChauffeurLoaded(:final chauffeurs) => chauffeurs,
      ChauffeurActionSuccess(:final chauffeurs) => chauffeurs,
      _ => <Chauffeur>[],
    };

    if (all.isEmpty) {
      return _EmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Aucun chauffeur',
        subtitle: 'Ajoutez votre premier chauffeur à la flotte.',
        actionLabel: 'Ajouter un chauffeur',
        onAction: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ChauffeurFormPage())),
      );
    }

    final chauffeurs = _filter(all);
    if (chauffeurs.isEmpty) {
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

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
        itemCount: chauffeurs.length,
        itemBuilder: (_, i) {
          final c = chauffeurs[i];
          return _ChauffeurCard(
            chauffeur: c,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChauffeurDetailPage(chauffeurId: c.id!),
              ),
            ),
            onEdit: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => ChauffeurFormPage(initial: c)),
            ),
            onDelete: () => _confirmDelete(c.id!, c.displayName),
          );
        },
      ),
    );
  }
}

// ── Carte chauffeur ──────────────────────────────────────────────────────────

class _ChauffeurCard extends StatelessWidget {
  final Chauffeur chauffeur;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ChauffeurCard({
    required this.chauffeur,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sc = _cStatutColor(chauffeur.statut);
    final avatarColor = _avatarColor(chauffeur.displayName);
    final initials =
        '${chauffeur.prenom.isNotEmpty ? chauffeur.prenom[0] : ''}'
                '${chauffeur.nom.isNotEmpty ? chauffeur.nom[0] : ''}'
            .toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          // Avatar
                          _ChauffeurThumbnail(
                            chauffeurId: chauffeur.id,
                            hasPhoto: chauffeur.photoUrl != null &&
                                chauffeur.photoUrl!.isNotEmpty,
                            initials: initials,
                            avatarColor: avatarColor,
                          ),
                          const SizedBox(width: 12),
                          // Infos
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(
                                    child: Text(
                                      chauffeur.displayName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF1A1A2E)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (chauffeur.type != null) ...[
                                    const SizedBox(width: 6),
                                    _TypeBadge(type: chauffeur.type!),
                                  ],
                                ]),
                                const SizedBox(height: 4),
                                _StatusChip(
                                  label: chauffeur.statut?.label ?? 'Inconnu',
                                  color: sc,
                                ),
                                const SizedBox(height: 7),
                                Wrap(spacing: 10, runSpacing: 3, children: [
                                  if (chauffeur.telephone != null)
                                    _MetaChip(
                                      icon: Icons.phone_outlined,
                                      label: chauffeur.telephone!,
                                      color: Colors.grey.shade700,
                                    ),
                                  if (chauffeur.vehiculeNom != null &&
                                      chauffeur.vehiculeNom!.isNotEmpty)
                                    _MetaChip(
                                      icon: Icons.directions_car_outlined,
                                      label: chauffeur.vehiculeNom!,
                                      color: Colors.grey.shade700,
                                    ),
                                ]),
                              ],
                            ),
                          ),
                          // Menu
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                color: Colors.grey.shade400, size: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            onSelected: (v) {
                              if (v == 'edit') onEdit();
                              if (v == 'delete') onDelete();
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('Modifier'),
                                ]),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  Icon(Icons.delete_outline,
                                      size: 18, color: Colors.red),
                                  SizedBox(width: 10),
                                  Text('Supprimer',
                                      style: TextStyle(color: Colors.red)),
                                ]),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Miniature chauffeur (photo ou initiales) ─────────────────────────────────

class _ChauffeurThumbnail extends StatefulWidget {
  final int? chauffeurId;
  final bool hasPhoto;
  final String initials;
  final Color avatarColor;

  const _ChauffeurThumbnail({
    this.chauffeurId,
    required this.hasPhoto,
    required this.initials,
    required this.avatarColor,
  });

  @override
  State<_ChauffeurThumbnail> createState() => _ChauffeurThumbnailState();
}

class _ChauffeurThumbnailState extends State<_ChauffeurThumbnail> {
  Future<Map<String, String>?>? _headersFuture;

  @override
  void initState() {
    super.initState();
    if (widget.hasPhoto && widget.chauffeurId != null) {
      _headersFuture = _buildAuthHeaders();
    }
  }

  Future<Map<String, String>?> _buildAuthHeaders() async {
    final token = await const SecureStorage().getAccessToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    Widget child;
    if (!widget.hasPhoto || widget.chauffeurId == null) {
      child = _initialsWidget(size);
    } else {
      final url =
          '${ApiConfig.baseUrl}/chauffeurs/${widget.chauffeurId}/photo';
      child = FutureBuilder<Map<String, String>?>(
        future: _headersFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _initialsWidget(size);
          }
          final headers = snap.data;
          if (headers == null) return _initialsWidget(size);
          return Image.network(
            url,
            headers: headers,
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _initialsWidget(size),
          );
        },
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(width: size, height: size, child: child),
    );
  }

  Widget _initialsWidget(double size) => Container(
        width: size,
        height: size,
        color: widget.avatarColor,
        child: Center(
          child: Text(
            widget.initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
      );
}

// ── Widgets partagés ─────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}

class _TypeBadge extends StatelessWidget {
  final TypeChauffeur type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final isPrincipal = type == TypeChauffeur.principal;
    final color =
        isPrincipal ? const Color(0xFF1565C0) : const Color(0xFF6A1B9A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(type.label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
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
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      );
}

// ── Skeletons ────────────────────────────────────────────────────────────────

class _SkeletonVList extends StatelessWidget {
  const _SkeletonVList();

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: 5,
        itemBuilder: (_, __) => const _SkeletonCard(tall: false),
      );
}

class _SkeletonCList extends StatelessWidget {
  const _SkeletonCList();

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
        itemCount: 5,
        itemBuilder: (_, __) => const _SkeletonCard(tall: true),
      );
}

class _SkeletonCard extends StatefulWidget {
  final bool tall;
  const _SkeletonCard({required this.tall});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Row(children: [
                    _Bone(
                        w: widget.tall ? 52 : 44,
                        h: widget.tall ? 52 : 44,
                        r: widget.tall ? 14 : 12,
                        opacity: _anim.value),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Bone(w: 140, h: 13, opacity: _anim.value),
                          const SizedBox(height: 6),
                          _Bone(w: 70, h: 10, opacity: _anim.value),
                          const SizedBox(height: 10),
                          Row(children: [
                            _Bone(w: 80, h: 10, opacity: _anim.value),
                            const SizedBox(width: 10),
                            _Bone(w: 60, h: 10, opacity: _anim.value),
                          ]),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double w, h, r, opacity;
  const _Bone(
      {required this.w, required this.h, this.r = 6, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey.shade300.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(r),
        ),
      );
}

// ── États communs ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

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
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded),
              label: Text(actionLabel),
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
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: Colors.orange.shade50, shape: BoxShape.circle),
                child: Icon(Icons.search_off_rounded,
                    size: 32, color: Colors.orange.shade400),
              ),
              const SizedBox(height: 16),
              const Text('Aucun résultat',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                  'Essayez un autre terme ou réinitialisez les filtres.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
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

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                    color: Colors.red.shade50, shape: BoxShape.circle),
                child: Icon(Icons.cloud_off_rounded,
                    size: 32, color: Colors.red.shade400),
              ),
              const SizedBox(height: 16),
              const Text('Erreur de chargement',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 13)),
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
