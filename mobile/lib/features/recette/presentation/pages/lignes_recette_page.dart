import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/encaissement.dart';
import '../../domain/entities/ligne_recette.dart';
import '../../domain/entities/ligne_recette_filtres.dart';
import '../providers/ligne_recette_provider.dart';
import '../providers/ligne_recette_state.dart';
import '../../../../core/widgets/encaissement_ligne_dialog.dart';
import '../../../../features/operation_financiere/presentation/providers/operation_financiere_provider.dart';
import '../../../../core/widgets/filtre_vehicule_chauffeur_dialog.dart';
import '../../../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../../../features/vehicule/domain/entities/vehicule.dart';
import 'ligne_recette_detail_page.dart';
import '../../../../core/widgets/date_filter_dialogs.dart';

// ── Constantes partagées ───────────────────────────────────────────────────

enum _FiltreMode { mois, semaine, jour, periode }

// ── Page principale ────────────────────────────────────────────────────────

class LignesRecettePage extends ConsumerStatefulWidget {
  const LignesRecettePage({super.key});

  @override
  ConsumerState<LignesRecettePage> createState() => _LignesRecettePageState();
}

class _LignesRecettePageState extends ConsumerState<LignesRecettePage> {
  _FiltreMode _filtreMode = _FiltreMode.mois;
  int _moisSelectionne = DateTime.now().month;
  int _anneeSelectionnee = DateTime.now().year;
  DateTime _jourSelectionne = DateTime.now();
  DateTime _semaineDebut = mondayOf(DateTime.now());
  DateTime _periodeDebut = DateTime.now().subtract(const Duration(days: 30));
  DateTime _periodeFin = DateTime.now();
  StatutLigneRecette? _statutFiltre;
  String _recherche = '';
  Vehicule?  _vehiculeFiltre;
  Chauffeur? _chauffeurFiltre;

  final _searchController = TextEditingController();
  OverlayEntry? _overlayEntry;
  final _filtreButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  Future<void> _showFiltreAvance() async {
    final result = await showFiltreVehiculeChauffeurDialog(
      context,
      vehiculeInitial:  _vehiculeFiltre,
      chauffeurInitial: _chauffeurFiltre,
      avecChauffeur:    true,
    );
    if (result != null && mounted) {
      setState(() {
        _vehiculeFiltre  = result.vehicule;
        _chauffeurFiltre = result.chauffeur;
      });
    }
  }

  void _load() {
    final (dateDebut, dateFin) = _plageActive();
    ref.read(ligneRecetteNotifierProvider.notifier).load(
          LigneRecetteFiltres(dateDebut: dateDebut, dateFin: dateFin),
        );
  }

  (DateTime, DateTime) _plageActive() {
    return switch (_filtreMode) {
      _FiltreMode.mois => (
          DateTime(_anneeSelectionnee, _moisSelectionne, 1),
          DateTime(_anneeSelectionnee, _moisSelectionne + 1, 0),
        ),
      _FiltreMode.semaine => (
          _semaineDebut,
          _semaineDebut.add(const Duration(days: 6)),
        ),
      _FiltreMode.jour => (_jourSelectionne, _jourSelectionne),
      _FiltreMode.periode => (_periodeDebut, _periodeFin),
    };
  }

  List<LigneRecette> _filtrer(List<LigneRecette> all) {
    final query = _recherche.toLowerCase();
    return all.where((l) {
      if (_vehiculeFiltre != null && l.vehiculeId != _vehiculeFiltre!.id) return false;
      if (_chauffeurFiltre != null && _chauffeurFiltre!.id != null && l.chauffeurId != _chauffeurFiltre!.id) return false;
      if (_statutFiltre != null && l.statut != _statutFiltre) return false;
      if (query.isNotEmpty) {
        final hay = [
          l.statut.label,
          '${l.vehiculeId}',
          '${l.chauffeurId}',
        ].join(' ').toLowerCase();
        if (!hay.contains(query)) return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.dateRecette.compareTo(a.dateRecette));
  }

  void _showFiltreOverlay() {
    _removeOverlay();
    final renderBox =
        _filtreButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _FiltreMode.values.map((mode) {
                      final label = switch (mode) {
                        _FiltreMode.mois => 'Mois',
                        _FiltreMode.semaine => 'Semaine',
                        _FiltreMode.jour => 'Jour',
                        _FiltreMode.periode => 'Période',
                      };
                      final sel = _filtreMode == mode;
                      return InkWell(
                        onTap: () {
                          setState(() => _filtreMode = mode);
                          _removeOverlay();
                          _load();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              Icon(
                                sel
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off_outlined,
                                size: 18,
                                color: sel
                                    ? const Color(0xFF43A047)
                                    : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: sel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: sel
                                      ? const Color(0xFF43A047)
                                      : const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _pickMois() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(
        initialYear: _anneeSelectionnee,
        initialMonth: _moisSelectionne,
      ),
    );
    if (result != null) {
      setState(() {
        _moisSelectionne = result.month;
        _anneeSelectionnee = result.year;
      });
      _load();
    }
  }

  Future<void> _pickSemaine() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => WeekPickerDialog(initialWeekStart: _semaineDebut),
    );
    if (result != null) {
      setState(() => _semaineDebut = result);
      _load();
    }
  }

  Future<void> _pickJour() async {
    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => SingleDatePickerDialog(initialDate: _jourSelectionne),
    );
    if (result != null) {
      setState(() => _jourSelectionne = result);
      _load();
    }
  }

  Future<void> _pickPeriode() async {
    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => PeriodePickerDialog(
        initialStart: _periodeDebut,
        initialEnd: _periodeFin,
      ),
    );
    if (result != null) {
      setState(() {
        _periodeDebut = result.start;
        _periodeFin = result.end;
      });
      _load();
    }
  }

  Future<void> _openEncaisserDialog(LigneRecette ligne) async {
    final repo   = ref.read(ligneRecetteRepositoryProvider);
    final result = await showEncaissementLigneDialog(
      context,
      titre:          'Recette',
      sousTitre:      ligne.vehiculeImmatriculation ?? 'Véhicule ${ligne.vehiculeId}',
      montantRestant: ligne.montantRestant,
      couleur:        const Color(0xFF2E7D32),
      icone:          Icons.account_balance_wallet_outlined,
      onEncaisser: (montant, commentaire) async {
        final enc = Encaissement(
          ligneRecetteId:   ligne.id!,
          montant:          montant,
          modeEncaissement: ModeEncaissement.especes,
          dateEncaissement: DateTime.now(),
          commentaire:      commentaire,
        );
        final r = await repo.createEncaissement(ligne.id!, enc);
        return r.fold((f) => f.message, (_) => null);
      },
    );
    if (result == true && mounted) {
      _load();
      ref.read(operationFinanciereNotifierProvider.notifier).loadAll();
    }
  }

  Future<void> _generer() async {
    final error = await ref
        .read(ligneRecetteNotifierProvider.notifier)
        .generer();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lignes d'hier générées avec succès.")),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final money =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'XOF', decimalDigits: 0);
    final state = ref.watch(ligneRecetteNotifierProvider);

    final allLignes = switch (state) {
      LigneRecetteLoaded(:final lignes) => lignes,
      LigneRecetteActionSuccess(:final lignes) => lignes,
      _ => <LigneRecette>[],
    };

    final filtered = _filtrer(allLignes);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ────────────────────────────────────────────────
            Container(
              color: AppColors.header,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 56,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          size: 18, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Recettes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _generer,
                    child: Container(
                      width: 56,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded,
                          size: 18, color: Color(0xFF1A1A2E)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Corps ──────────────────────────────────────────────────
            Expanded(
              child: state is LigneRecetteLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: CustomScrollView(
                        slivers: [
                          // ── Filtre date ──────────────────────────────
                          SliverToBoxAdapter(
                            child: _FiltreBar(
                              mode: _filtreMode,
                              filtreKey: _filtreButtonKey,
                              onFiltrePressed: _showFiltreOverlay,
                              moisSelectionne: _moisSelectionne,
                              anneeSelectionnee: _anneeSelectionnee,
                              onPickMois: _pickMois,
                              semaineDebut: _semaineDebut,
                              onPickSemaine: _pickSemaine,
                              jourSelectionne: _jourSelectionne,
                              onPickJour: _pickJour,
                              periodeDebut: _periodeDebut,
                              periodeFin: _periodeFin,
                              onPickPeriode: _pickPeriode,
                            ),
                          ),

                          // ── Filtre statut + recherche ────────────────
                          SliverToBoxAdapter(
                            child: _SearchAndStatutBar(
                              controller: _searchController,
                              onSearchChanged: (v) =>
                                  setState(() => _recherche = v),
                              statutSelectionne: _statutFiltre,
                              onStatutChanged: (s) =>
                                  setState(() => _statutFiltre = s),
                              onTunePressed:   _showFiltreAvance,
                              hasActiveFilter: _vehiculeFiltre != null || _chauffeurFiltre != null,
                            ),
                          ),

                          // ── Liste ou état vide ───────────────────────
                          if (filtered.isEmpty)
                            const SliverFillRemaining(child: _EmptyState())
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) => _LigneCard(
                                    ligne: filtered[i],
                                    money: money,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => LigneRecetteDetailPage(
                                          ligneId: filtered[i].id!,
                                        ),
                                      ),
                                    ).then((_) => _load()),
                                    onEncaisser: filtered[i].estActive
                                        ? () => _openEncaisserDialog(filtered[i])
                                        : null,
                                  ),
                                  childCount: filtered.length,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre filtre date ──────────────────────────────────────────────────────

class _FiltreBar extends StatelessWidget {
  final _FiltreMode mode;
  final GlobalKey filtreKey;
  final VoidCallback onFiltrePressed;
  final int moisSelectionne;
  final int anneeSelectionnee;
  final VoidCallback onPickMois;
  final DateTime semaineDebut;
  final VoidCallback onPickSemaine;
  final DateTime jourSelectionne;
  final VoidCallback onPickJour;
  final DateTime periodeDebut;
  final DateTime periodeFin;
  final VoidCallback onPickPeriode;

  const _FiltreBar({
    required this.mode,
    required this.filtreKey,
    required this.onFiltrePressed,
    required this.moisSelectionne,
    required this.anneeSelectionnee,
    required this.onPickMois,
    required this.semaineDebut,
    required this.onPickSemaine,
    required this.jourSelectionne,
    required this.onPickJour,
    required this.periodeDebut,
    required this.periodeFin,
    required this.onPickPeriode,
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = switch (mode) {
      _FiltreMode.mois => 'Mois',
      _FiltreMode.semaine => 'Semaine',
      _FiltreMode.jour => 'Jour',
      _FiltreMode.periode => 'Période',
    };

    final datePill = switch (mode) {
      _FiltreMode.mois => _DatePill(
          icon: Icons.calendar_month_outlined,
          label: '${kMoisNoms[moisSelectionne - 1]} $anneeSelectionnee',
          onTap: onPickMois,
        ),
      _FiltreMode.semaine => _DatePill(
          icon: Icons.date_range_outlined,
          label:
              '${DateFormat('dd/MM').format(semaineDebut)} – ${DateFormat('dd/MM/yyyy').format(semaineDebut.add(const Duration(days: 6)))}',
          onTap: onPickSemaine,
        ),
      _FiltreMode.jour => _DatePill(
          icon: Icons.calendar_today_outlined,
          label: DateFormat('dd/MM/yyyy').format(jourSelectionne),
          onTap: onPickJour,
        ),
      _FiltreMode.periode => _DatePill(
          icon: Icons.calendar_month_outlined,
          label:
              'Du ${DateFormat('dd/MM/yyyy').format(periodeDebut)} au ${DateFormat('dd/MM/yyyy').format(periodeFin)}',
          onTap: onPickPeriode,
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            key: filtreKey,
            onTap: onFiltrePressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list_rounded,
                      size: 14, color: Color(0xFF43A047)),
                  const SizedBox(width: 5),
                  Text(
                    modeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF43A047),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.keyboard_arrow_down_rounded,
                      size: 14, color: Color(0xFF43A047)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: datePill),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DatePill({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 5),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }
}

// ── Barre recherche + filtre statut ───────────────────────────────────────

class _SearchAndStatutBar extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final StatutLigneRecette? statutSelectionne;
  final void Function(StatutLigneRecette?) onStatutChanged;
  final VoidCallback? onTunePressed;
  final bool hasActiveFilter;

  const _SearchAndStatutBar({
    required this.controller,
    required this.onSearchChanged,
    required this.statutSelectionne,
    required this.onStatutChanged,
    this.onTunePressed,
    this.hasActiveFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF8A8A8E), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle:
                        TextStyle(color: Color(0xFF8A8A8E), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              TuneFilterButton(
                onTap:  onTunePressed,
                active: hasActiveFilter,
              ),
            ],
          ),
        ),
        // Chips de filtre statut
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _StatutChip(
                label: 'Tous',
                selected: statutSelectionne == null,
                color: Colors.grey.shade600,
                onTap: () => onStatutChanged(null),
              ),
              ...StatutLigneRecette.values.map((s) => _StatutChip(
                    label: s.label,
                    selected: statutSelectionne == s,
                    color: _couleurStatut(s),
                    onTap: () => onStatutChanged(s),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Color _couleurStatut(StatutLigneRecette s) => switch (s) {
        StatutLigneRecette.enAttente => Colors.orange,
        StatutLigneRecette.partiellementEncaisse => Colors.blue,
        StatutLigneRecette.encaisse => Colors.green,
        StatutLigneRecette.annulee => Colors.grey,
      };
}

class _StatutChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatutChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ── Carte ligne de recette ────────────────────────────────────────────────

class _LigneCard extends StatelessWidget {
  final LigneRecette ligne;
  final NumberFormat money;
  final VoidCallback  onTap;
  final VoidCallback? onEncaisser;

  const _LigneCard({
    required this.ligne,
    required this.money,
    required this.onTap,
    this.onEncaisser,
  });

  String _labelDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;

    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Hier';
    if (diff < 7) {
      const jours = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
      return jours[date.weekday - 1];
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final color = _couleurStatut(ligne.statut);
    final montantRestant = ligne.montantAttendu != null
        ? (ligne.montantAttendu! - ligne.montantEncaisse).clamp(0, double.infinity)
        : null;
    final montantAttenduDifferent = montantRestant != null &&
        montantRestant != ligne.montantAttendu;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icône statut
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconeStatut(ligne.statut), color: color, size: 19),
            ),
            const SizedBox(width: 12),

            // Infos gauche
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ligne.vehiculeImmatriculation ?? 'Véhicule ${ligne.vehiculeId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _labelDate(ligne.dateRecette),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Montants + bouton encaisser (droite)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (montantRestant != null)
                  Text(
                    '${NumberFormat('#,##0', 'fr_FR').format(montantRestant)} XOF',
                    style: TextStyle(
                      color: montantRestant > 0
                          ? Colors.orange.shade700
                          : const Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                else
                  Text(
                    '+${NumberFormat('#,##0', 'fr_FR').format(ligne.montantEncaisse)} XOF',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                if (montantAttenduDifferent)
                  Text(
                    'sur ${NumberFormat('#,##0', 'fr_FR').format(ligne.montantAttendu)} XOF',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                  ),
                if (onEncaisser != null) ...[
                  const SizedBox(height: 6),
                  EncaisserChip(onTap: onEncaisser!),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _couleurStatut(StatutLigneRecette s) => switch (s) {
        StatutLigneRecette.enAttente => Colors.orange,
        StatutLigneRecette.partiellementEncaisse => Colors.blue,
        StatutLigneRecette.encaisse => Colors.green,
        StatutLigneRecette.annulee => Colors.grey,
      };

  IconData _iconeStatut(StatutLigneRecette s) => switch (s) {
        StatutLigneRecette.enAttente => Icons.hourglass_empty_rounded,
        StatutLigneRecette.partiellementEncaisse => Icons.hourglass_top_rounded,
        StatutLigneRecette.encaisse => Icons.check_circle_rounded,
        StatutLigneRecette.annulee => Icons.cancel_rounded,
      };
}


// ── État vide ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(Icons.receipt_long_outlined,
                  size: 38, color: Colors.grey.shade300),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune ligne de recette',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Appuyez sur ✨ pour générer les lignes du jour',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

