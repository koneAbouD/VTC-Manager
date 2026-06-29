import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';

import '../../../../core/network/api_config.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../condition_travail/domain/entities/programme_chauffeur.dart';
import '../../../condition_travail/domain/entities/programme_travail.dart';
import '../../../condition_travail/domain/enums/mode_alternance.dart';
import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../providers/chauffeur_provider.dart';
import '../providers/chauffeur_state.dart';
import '../providers/documents_by_chauffeur_provider.dart';
import '../../../indisponibilite/domain/entities/indisponibilite.dart';
import '../../../indisponibilite/presentation/indisponibilite_overlay.dart';
import '../../../indisponibilite/presentation/providers/indisponibilite_provider.dart';
import 'chauffeur_form_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../vehicule/presentation/pages/vehicule_detail_page.dart';

export '../providers/chauffeur_provider.dart' show chauffeurPhotoVersionProvider;

/// Écran de détail d'un chauffeur.
///
/// Aligné sur l'entité domaine [Chauffeur] refactorisée (enums `.label`,
/// liste `permisConduire`, `photoUrl` streamé depuis `/chauffeurs/{id}/photo`).
class ChauffeurDetailPage extends ConsumerStatefulWidget {
  final int chauffeurId;
  final int initialTabIndex;
  final bool canPopToVehicule;
  const ChauffeurDetailPage({super.key, required this.chauffeurId, this.initialTabIndex = 0, this.canPopToVehicule = false});

  @override
  ConsumerState<ChauffeurDetailPage> createState() =>
      _ChauffeurDetailPageState();
}

class _ChauffeurDetailPageState extends ConsumerState<ChauffeurDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncChauffeur = ref.watch(chauffeurByIdProvider(widget.chauffeurId));

    // Rafraîchir après une modification via le notifier.
    ref.listen(chauffeurNotifierProvider, (prev, next) {
      if (next is ChauffeurLoaded || next is ChauffeurActionSuccess) {
        ref.invalidate(chauffeurByIdProvider(widget.chauffeurId));
      }
    });

    return Scaffold(
      appBar: AppHeader(
        title: '',
        action: asyncChauffeur.valueOrNull == null
            ? null
            : AppHeaderAction(
                label: 'Modifier',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChauffeurFormPage(
                      initial: asyncChauffeur.valueOrNull!,
                    ),
                  ),
                ),
              ),
      ),
      body: asyncChauffeur.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : $e', textAlign: TextAlign.center),
          ),
        ),
        data: (c) => _DetailBody(chauffeur: c, tabController: _tab, canPopToVehicule: widget.canPopToVehicule),
      ),
    );
  }
}

// ── Corps de l'écran ─────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  final Chauffeur chauffeur;
  final TabController tabController;
  final bool canPopToVehicule;

  const _DetailBody({required this.chauffeur, required this.tabController, this.canPopToVehicule = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        _HeaderCard(chauffeur: chauffeur),
        const SizedBox(height: 12),
        _PillTabBar(controller: tabController, tabs: const [
          _PillTabItem(label: 'Infos', icon: Icons.info_outline),
          _PillTabItem(label: 'Documents', icon: Icons.folder_outlined),
          _PillTabItem(label: 'Programmes', icon: Icons.people_outline),
          _PillTabItem(label: 'Recettes', icon: Icons.payments_outlined),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _InfoGeneralesTab(chauffeur: chauffeur),
              _DocumentsTab(chauffeur: chauffeur),
              _ProgrammesTab(chauffeur: chauffeur, canPopToVehicule: canPopToVehicule),
              const _PlaceholderTab(label: 'Recettes à venir'),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header : photo, nom, téléphone, statut, badge type ───────────────────────

class _HeaderCard extends StatelessWidget {
  final Chauffeur chauffeur;
  const _HeaderCard({required this.chauffeur});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF6F8FF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F5)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: (chauffeur.photoUrl != null &&
                        chauffeur.photoUrl!.isNotEmpty)
                    ? () => showDialog<void>(
                          context: context,
                          barrierColor: Colors.black.withValues(alpha: 0.55),
                          builder: (_) => _PhotoFullscreenViewer(
                            chauffeurId: chauffeur.id,
                            photoBase64: chauffeur.photoBase64,
                          ),
                        )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: ChauffeurAvatar(
                      chauffeurId: chauffeur.id,
                      initials: _initials(chauffeur),
                      hasPhoto: chauffeur.photoUrl != null &&
                          chauffeur.photoUrl!.isNotEmpty,
                      size: 64,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chauffeur.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 19,
                        color: Color(0xFF1A1A2E),
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatPhone(chauffeur.telephone),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: chauffeur.statut),
            ],
          ),
          const SizedBox(height: 14),
          _StatChip(
            icon: Icons.directions_car_outlined,
            label: chauffeur.vehiculeMatricule ?? 'Aucun véhicule',
            accent: chauffeur.vehiculeMatricule != null
                ? AppColors.primary
                : null,
          ),
        ],
      ),
    );
  }

  static String _initials(Chauffeur c) {
    final p = c.prenom.isNotEmpty ? c.prenom[0] : '';
    final n = c.nom.isNotEmpty ? c.nom[0] : '';
    return (p + n).toUpperCase();
  }

  static String _formatPhone(String? raw) {
    if (raw == null || raw.isEmpty) return 'Téléphone non renseigné';
    if (raw.startsWith('+')) {
      final match = RegExp(r'^(\+\d{1,4})(\d+)$').firstMatch(raw);
      if (match != null) return '${match.group(1)} ${match.group(2)}';
    }
    return raw;
  }
}

class _StatusPill extends StatelessWidget {
  final ChauffeurStatus? status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label, icon) = switch (status) {
      ChauffeurStatus.actif => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
          'Actif',
          Icons.check_circle,
        ),
      ChauffeurStatus.enService => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
          'En service',
          Icons.directions_car,
        ),
      ChauffeurStatus.enConge => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          'En congé',
          Icons.beach_access,
        ),
      ChauffeurStatus.suspendu => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          'Suspendu',
          Icons.cancel,
        ),
      ChauffeurStatus.inactif => (
          const Color(0xFFEFEFEF),
          const Color(0xFF616161),
          'Inactif',
          Icons.pause_circle,
        ),
      _ => (
          const Color(0xFFEFEFEF),
          const Color(0xFF616161),
          '—',
          Icons.help_outline,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? accent;

  const _StatChip({required this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    final fg = accent ?? const Color(0xFF42476B);
    final bg = (accent ?? const Color(0xFF6B7794)).withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill Tab Bar ─────────────────────────────────────────────────────────

class _PillTabItem {
  final String label;
  final IconData icon;
  const _PillTabItem({required this.label, required this.icon});
}

class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final List<_PillTabItem> tabs;
  const _PillTabBar({required this.controller, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E9F5)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF6B7794),
        labelStyle: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500, fontSize: 13),
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        tabs: tabs
            .map((t) => Tab(
                  height: 36,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 15),
                      const SizedBox(width: 6),
                      Text(t.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Onglet Informations générales ────────────────────────────────────────────

class _InfoGeneralesTab extends StatelessWidget {
  final Chauffeur chauffeur;
  const _InfoGeneralesTab({required this.chauffeur});

  @override
  Widget build(BuildContext context) {
    final dn = chauffeur.dateNaissance;
    final de = chauffeur.dateEmbauche;
    final ds = chauffeur.geolocalisation?.horodatage;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _SectionCard(
          title: 'Détails du chauffeur',
          icon: Icons.person_outline,
          children: [
            _InfoRow(
              label: 'Nom',
              value: chauffeur.nom,
              icon: Icons.badge_outlined,
            ),
            _InfoRow(
              label: 'Prénom',
              value: chauffeur.prenom,
              icon: Icons.badge_outlined,
            ),
            _InfoRow(
              label: 'Adresse e-mail',
              value: chauffeur.email,
              icon: Icons.email_outlined,
            ),
            _InfoRow(
              label: 'Numéro de téléphone',
              value: _HeaderCard._formatPhone(chauffeur.telephone),
              icon: Icons.phone_outlined,
            ),
            _InfoRow(
              label: 'Sexe',
              value: chauffeur.genre?.label,
              icon: Icons.wc_outlined,
            ),
            _InfoRow(
              label: 'Type de chauffeur',
              value: chauffeur.type?.label,
              icon: Icons.work_outline,
            ),
            _InfoRow(
              label: 'Adresse',
              value: chauffeur.adresse,
              icon: Icons.location_on_outlined,
            ),
            _InfoRow(
              label: 'Date de naissance',
              value: _formatDate(dn),
              icon: Icons.cake_outlined,
            ),
            if (chauffeur.age != null)
              _InfoRow(
                label: 'Âge',
                value: '${chauffeur.age} ans',
                icon: Icons.calendar_today_outlined,
              ),
            _InfoRow(
              label: "Date d'embauche",
              value: _formatDate(de),
              icon: Icons.work_history_outlined,
            ),
            _InfoRow(
              label: 'Véhicule assigné',
              value: _vehiculeLabel(chauffeur),
              icon: Icons.directions_car_outlined,
            ),
            _InfoRow(
              label: 'Dernière session',
              value: _formatDateTime(ds),
              icon: Icons.access_time_outlined,
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static String? _vehiculeLabel(Chauffeur c) => c.vehiculeMatricule;

  static String? _formatDate(DateTime? d) {
    if (d == null) return null;
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  static String? _formatDateTime(DateTime? d) {
    if (d == null) return null;
    final date = _formatDate(d);
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$date à $hh:$mm';
  }
}

// ── Onglet Documents ─────────────────────────────────────────────────────────

class _ProgrammesTab extends ConsumerStatefulWidget {
  final Chauffeur chauffeur;
  final bool canPopToVehicule;
  const _ProgrammesTab({required this.chauffeur, this.canPopToVehicule = false});

  @override
  ConsumerState<_ProgrammesTab> createState() => _ProgrammesTabState();
}

class _ProgrammesTabState extends ConsumerState<_ProgrammesTab> {
  /// Overlay des indisponibilités (recalculé à chaque build).
  IndisponibiliteOverlay _overlay = const IndisponibiliteOverlay([]);
  static const _weekdayLabels = [
    'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];

  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  Chauffeur get chauffeur => widget.chauffeur;

  @override
  void initState() {
    super.initState();
    final now = _dateOnly(DateTime.now());
    _focusedMonth = DateTime(now.year, now.month);

    final programme = chauffeur.programmeTravail;
    final pc = _findPc(programme);
    if (programme != null && pc != null) {
      _selectedDate =
          ChauffeurProgrammeCalculator.scheduleForDate(programme, pc, now) != null
              ? now
              : null;
    }
  }

  ProgrammeChauffeur? _findPc(ProgrammeTravail? programme) {
    if (programme == null || programme.chauffeurs.isEmpty) return null;
    try {
      return programme.chauffeurs
          .firstWhere((p) => p.chauffeurId == chauffeur.id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final programme = chauffeur.programmeTravail;
    _overlay = IndisponibiliteOverlay(
        ref.watch(toutesIndisponibilitesProvider).valueOrNull ?? const []);

    if (programme == null || programme.id == null || programme.chauffeurs.isEmpty) {
      return _ProgrammeEmptyState(
        icon: chauffeur.vehiculeId == null
            ? Icons.no_transfer_rounded
            : Icons.calendar_month_outlined,
        title: chauffeur.vehiculeId == null
            ? 'Aucun véhicule assigné'
            : 'Aucun programme configuré',
        description: chauffeur.vehiculeId == null
            ? 'Assignez un véhicule à ce chauffeur pour consulter son calendrier de travail.'
            : 'Le véhicule ${chauffeur.vehiculeNom ?? 'assigné'} n\'a pas encore de programme actif.',
      );
    }

    final pc = _findPc(programme);
    if (pc == null) {
      return _ProgrammeEmptyState(
        icon: Icons.person_off_outlined,
        title: 'Chauffeur non planifié',
        description:
            'Ce chauffeur n\'est pas inclus dans le programme actif du véhicule ${chauffeur.vehiculeNom ?? ''}.',
      );
    }

    // (b) Programmes des titulaires que ce chauffeur remplace, pour afficher le
    // véhicule emprunté sur son calendrier.
    final indisposCommeRemplacant =
        (ref.watch(toutesIndisponibilitesProvider).valueOrNull ?? const [])
            .where((i) => i.chauffeurRemplacantId == chauffeur.id)
            .toList();
    final Map<int, Chauffeur> titulaires = {};
    for (final i in indisposCommeRemplacant) {
      final tit = ref.watch(chauffeurByIdProvider(i.chauffeurId)).valueOrNull;
      if (tit != null) titulaires[i.chauffeurId] = tit;
    }

    final calendarDays = _buildCalendarDays(
        programme, pc, _focusedMonth, indisposCommeRemplacant, titulaires);
    final selectedIndispo = (_selectedDate != null && chauffeur.id != null)
        ? _overlay.remplacementDuTitulaire(chauffeur.id!, _selectedDate!)
        : null;
    final selectedBorrow = _selectedDate != null
        ? _borrowForDate(_selectedDate!, indisposCommeRemplacant, titulaires)
        : null;
    final selectedSchedule = (_selectedDate != null && selectedIndispo == null)
        ? ChauffeurProgrammeCalculator.scheduleForDate(
            programme, pc, _selectedDate!)
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // ── Calendrier ──
        Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  _monthArrow(Icons.chevron_left_rounded, () => _changeMonth(-1)),
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy', 'fr_FR').format(_focusedMonth),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  _monthArrow(Icons.chevron_right_rounded, () => _changeMonth(1)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: _weekdayLabels
                    .map((l) => Expanded(
                          child: Text(
                            l,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 4),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: calendarDays.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 1,
                  crossAxisSpacing: 1,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (_, i) => _buildCell(calendarDays[i]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // ── Légende ──
        const Row(
          children: [
            _ChauffeurLegendChip(
              color: Color(0xFFD9E5FF),
              label: 'Jour de travail',
            ),
            SizedBox(width: 14),
            _ChauffeurLegendChip(
              color: Color(0xFFCDEDD8),
              label: 'Jour de salaire',
            ),
          ],
        ),
        const SizedBox(height: 14),
        // ── Card véhicule ──
        _buildVehiculeCard(programme, selectedSchedule,
            remplacePar: selectedIndispo?.chauffeurRemplacantNom,
            borrow: selectedBorrow),
      ],
    );
  }

  Widget _buildCell(_ChauffeurCalendarCell day) {
    final schedule = day.schedule;
    final inMonth = day.inMonth;
    final isSelected =
        _selectedDate != null && _isSameDate(_selectedDate!, day.date);
    final isToday = _isSameDate(day.date, DateTime.now());
    final indispo = day.indisponible && inMonth;
    final remplacant = day.estRemplacant && inMonth;
    // Indisponibilité et remplacement restent sélectionnables pour voir le détail.
    final isEnabled = (schedule != null || indispo || remplacant) && inMonth;

    // Les jours hors du mois sont toujours grisés
    final background = isSelected
        ? const Color(0xFF325DBB)
        : !inMonth
            ? const Color(0xFFF0F0F0)
            : indispo
                ? const Color(0xFFFFE0E0) // indisponible → rouge clair
                : remplacant
                    ? const Color(0xFFFFE9D1) // remplacement → orange clair
                    : schedule == null
                        ? Colors.white
                        : schedule.isSalaryDay
                            ? const Color(0xFFCDEDD8)
                            : const Color(0xFFD9E5FF);

    final textColor = isSelected
        ? Colors.white
        : !inMonth
            ? const Color(0xFFBDBDBD)
            : indispo
                ? const Color(0xFFC62828)
                : remplacant
                    ? const Color(0xFFE65100)
                    : schedule == null
                        ? const Color(0xFF4A5468)
                        : const Color(0xFF304160);

    return Material(
      color: background,
      child: InkWell(
        onTap: !isEnabled
            ? null
            : () => setState(() => _selectedDate = day.date),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday
                  ? const Color(0xFF8BA4E8)
                  : const Color(0xFFEEEEEE),
              width: 0.5,
            ),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${day.date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (indispo && !isSelected)
                const Text(
                  'indispo',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC62828),
                    height: 1.0,
                  ),
                ),
              if (remplacant && !isSelected)
                const Text(
                  'remp.',
                  style: TextStyle(
                    fontSize: 6,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFE65100),
                    height: 1.0,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehiculeCard(ProgrammeTravail programme, ChauffeurProgrammeDay? day,
      {String? remplacePar, ({String vehicule, String titulaireNom})? borrow}) {
    final timeRange = ChauffeurProgrammeCalculator.timeRange(programme);
    final isSalaryDay = day?.isSalaryDay ?? false;
    final estIndisponible = remplacePar != null;
    final estRemplacant = borrow != null;

    final matricule = estRemplacant
        ? borrow.vehicule
        : (chauffeur.vehiculeMatricule ?? chauffeur.vehiculeNom ?? '—');

    final String vehiculeStatut;
    if (estIndisponible) {
      vehiculeStatut = 'Indisponible · remplacé par $remplacePar';
    } else if (estRemplacant) {
      vehiculeStatut = 'Remplacement · remplace ${borrow.titulaireNom}';
    } else if (_selectedDate == null) {
      vehiculeStatut = 'Véhicule assigné';
    } else if (day != null && day.isServiceDay) {
      vehiculeStatut = 'En service';
    } else {
      vehiculeStatut = 'Hors service';
    }

    final rowColor = estIndisponible
        ? const Color(0xFFC62828)
        : estRemplacant
            ? const Color(0xFFE65100)
            : isSalaryDay ? const Color(0xFF2E7D32) : const Color(0xFF3158B6);
    final rowBg = estIndisponible
        ? const Color(0xFFFFE0E0)
        : estRemplacant
            ? const Color(0xFFFFF3E0)
            : isSalaryDay ? const Color(0xFFE8F5E9) : const Color(0xFFEAF1FF);
    final borderColor = estIndisponible
        ? const Color(0xFFF5C2C2)
        : estRemplacant
            ? const Color(0xFFF5D6B0)
            : isSalaryDay ? const Color(0xFFC8E6C9) : const Color(0xFFE4E9F5);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedDate != null) ...[
            Text(
              DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate!),
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
          ],
          _buildDetailRow(
            icon: Icons.directions_car_outlined,
            label: vehiculeStatut,
            name: matricule,
            detail: estRemplacant || (day != null && day.isServiceDay)
                ? timeRange
                : '',
            color: rowColor,
            bg: rowBg,
            // Pour un jour de remplacement, le véhicule appartient au titulaire
            // (pas de navigation directe ici).
            onTap: (!estRemplacant && chauffeur.vehiculeId != null)
                ? () {
                    if (widget.canPopToVehicule) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => VehiculeDetailPage(
                          vehiculeId: chauffeur.vehiculeId!,
                          initialTabIndex: 2,
                          canPopToChauffeur: true,
                        ),
                      ));
                    }
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String name,
    required String detail,
    required Color color,
    required Color bg,
    VoidCallback? onTap,
  }) {
    final inner = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.8),
                  ),
                ),
                Text(
                  detail.isEmpty ? name : '$name  $detail',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.5)),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: bg,
        child: onTap != null ? InkWell(onTap: onTap, child: inner) : inner,
      ),
    );
  }

  List<_ChauffeurCalendarCell> _buildCalendarDays(
    ProgrammeTravail programme,
    ProgrammeChauffeur pc,
    DateTime focusedMonth,
    List<Indisponibilite> indisposCommeRemplacant,
    Map<int, Chauffeur> titulaires,
  ) {
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month);
    final gridStart =
        monthStart.subtract(Duration(days: monthStart.weekday - 1));
    return List.generate(42, (index) {
      final date = _dateOnly(gridStart.add(Duration(days: index)));
      final indispo = chauffeur.id != null
          ? _overlay.remplacementDuTitulaire(chauffeur.id!, date)
          : null;
      final borrow = indispo != null
          ? null
          : _borrowForDate(date, indisposCommeRemplacant, titulaires);
      return _ChauffeurCalendarCell(
        date: date,
        inMonth: date.month == focusedMonth.month,
        // (a) Pendant son indisponibilité, le titulaire ne travaille pas.
        schedule: indispo != null
            ? null
            : ChauffeurProgrammeCalculator.scheduleForDate(
                programme, pc, date),
        indisponible: indispo != null,
        remplacantNom: indispo?.chauffeurRemplacantNom,
        remplaceVehicule: borrow?.vehicule,
        remplaceTitulaireNom: borrow?.titulaireNom,
      );
    });
  }

  /// (b) Si ce chauffeur remplace un titulaire qui conduit ce jour-là, renvoie
  /// le véhicule emprunté et le nom du titulaire.
  ({String vehicule, String titulaireNom})? _borrowForDate(
    DateTime date,
    List<Indisponibilite> indisposCommeRemplacant,
    Map<int, Chauffeur> titulaires,
  ) {
    for (final i in indisposCommeRemplacant) {
      if (!IndisponibiliteOverlay.couvre(i, date)) continue;
      final tit = titulaires[i.chauffeurId];
      final titProgramme = tit?.programmeTravail;
      if (tit == null || titProgramme == null) continue;

      ProgrammeChauffeur? titPc;
      for (final p in titProgramme.chauffeurs) {
        if (p.chauffeurId == i.chauffeurId) {
          titPc = p;
          break;
        }
      }
      if (titPc == null) continue;

      final sched = ChauffeurProgrammeCalculator.scheduleForDate(
          titProgramme, titPc, date);
      if (sched != null && sched.isServiceDay) {
        return (
          vehicule: tit.vehiculeMatricule ?? tit.vehiculeNom ?? 'Véhicule',
          titulaireNom: i.chauffeurNom ?? 'titulaire',
        );
      }
    }
    return null;
  }

  Widget _monthArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: const Color(0xFF2A3147), size: 24),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth =
          DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ChauffeurLegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _ChauffeurLegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const _MiniBadge({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ProgrammeEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Icon(icon, color: const Color(0xFF3158B6), size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChauffeurProgrammeCalendarSheet extends StatefulWidget {
  final Chauffeur chauffeur;
  final ProgrammeTravail programme;
  final ProgrammeChauffeur programmeChauffeur;

  const _ChauffeurProgrammeCalendarSheet({
    required this.chauffeur,
    required this.programme,
    required this.programmeChauffeur,
  });

  @override
  State<_ChauffeurProgrammeCalendarSheet> createState() =>
      _ChauffeurProgrammeCalendarSheetState();
}

class _ChauffeurProgrammeCalendarSheetState
    extends State<_ChauffeurProgrammeCalendarSheet> {
  static const _weekdayLabels = [
    'Lun',
    'Mar',
    'Mer',
    'Jeu',
    'Ven',
    'Sam',
    'Dim',
  ];

  late DateTime _focusedMonth;
  DateTime? _selectedDate;

  Chauffeur get chauffeur => widget.chauffeur;
  ProgrammeTravail get programme => widget.programme;
  ProgrammeChauffeur get programmeChauffeur => widget.programmeChauffeur;

  @override
  void initState() {
    super.initState();
    final initialDate = ChauffeurProgrammeCalculator.initialSelectedDate(
          programme,
          programmeChauffeur,
        ) ??
        _dateOnly(DateTime.now());
    _focusedMonth = DateTime(initialDate.year, initialDate.month);
    _selectedDate = ChauffeurProgrammeCalculator.scheduleForDate(
              programme,
              programmeChauffeur,
              initialDate,
            ) !=
            null
        ? initialDate
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendarDays = _buildCalendarDays(_focusedMonth);
    final selectedSchedule = _selectedDate == null
        ? null
        : ChauffeurProgrammeCalculator.scheduleForDate(
            programme,
            programmeChauffeur,
            _selectedDate!,
          );

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6F7FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7DCEC),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Calendrier du chauffeur',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Les dates colorees montrent les jours de travail ou de salaire de ${chauffeur.fullName}.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _monthArrow(
                            icon: Icons.chevron_left_rounded,
                            onTap: () => _changeMonth(-1),
                          ),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy', 'fr_FR').format(_focusedMonth),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          _monthArrow(
                            icon: Icons.chevron_right_rounded,
                            onTap: () => _changeMonth(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: _weekdayLabels
                            .map(
                              (label) => Expanded(
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: calendarDays.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final day = calendarDays[index];
                          final isSelected = _selectedDate != null &&
                              _isSameDate(_selectedDate!, day.date);
                          return _buildDayCell(day, isSelected: isSelected);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _selectedDate == null
                      ? DateFormat('d MMMM yyyy', 'fr_FR')
                          .format(_dateOnly(DateTime.now()))
                      : DateFormat('d MMMM yyyy', 'fr_FR').format(_selectedDate!),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: selectedSchedule == null
                      ? _calendarHint()
                      : _selectedDayCard(selectedSchedule),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_ChauffeurCalendarCell> _buildCalendarDays(DateTime focusedMonth) {
    final monthStart = DateTime(focusedMonth.year, focusedMonth.month);
    final gridStart = monthStart.subtract(Duration(days: monthStart.weekday - 1));
    return List.generate(42, (index) {
      final date = _dateOnly(gridStart.add(Duration(days: index)));
      return _ChauffeurCalendarCell(
        date: date,
        inMonth: date.month == focusedMonth.month,
        schedule: ChauffeurProgrammeCalculator.scheduleForDate(
          programme,
          programmeChauffeur,
          date,
        ),
      );
    });
  }

  Widget _monthArrow({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, color: const Color(0xFF2A3147), size: 24),
      ),
    );
  }

  Widget _buildDayCell(
    _ChauffeurCalendarCell day, {
    required bool isSelected,
  }) {
    final schedule = day.schedule;
    final inMonth = day.inMonth;
    final isToday = _isSameDate(day.date, DateTime.now());
    final isEnabled = schedule != null && inMonth;

    final background = isSelected
        ? const Color(0xFF325DBB)
        : schedule == null
            ? (inMonth ? Colors.white : const Color(0xFFF1F2F6))
            : schedule.isServiceDay && schedule.isSalaryDay
                ? const Color(0xFFBFD2FF)
                : schedule.isServiceDay
                    ? const Color(0xFFD9E5FF)
                    : const Color(0xFFFFF0C7);

    final textColor = isSelected
        ? Colors.white
        : schedule == null
            ? (inMonth ? const Color(0xFF4A5468) : const Color(0xFFC9CEDB))
            : const Color(0xFF304160);

    return Material(
      color: background,
      child: InkWell(
        onTap: !isEnabled
            ? null
            : () => setState(() {
                  _selectedDate = day.date;
                }),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isToday
                  ? const Color(0xFF8BA4E8)
                  : const Color(0xFFE6EAF2),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.date.day}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _calendarHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF4FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Text(
        'Selectionnez une case coloree pour voir le programme du chauffeur a cette date.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.45,
          color: Color(0xFF33415C),
        ),
      ),
    );
  }

  Widget _selectedDayCard(ChauffeurProgrammeDay day) {
    final title = switch ((day.isServiceDay, day.isSalaryDay)) {
      (true, true) => 'Jour de travail et de salaire',
      (true, false) => 'Jour de travail',
      (false, true) => 'Jour de salaire',
      _ => 'Programme du jour',
    };

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A2E).withValues(alpha: 0.06),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      _initials(chauffeur),
                      style: const TextStyle(
                        color: Color(0xFF325DBB),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
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
                          fontSize: 17,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2F3A4E),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  DateFormat('dd/MM/yyyy').format(day.date),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (chauffeur.vehiculeNom != null && chauffeur.vehiculeNom!.isNotEmpty)
                  _MiniBadge(
                    label: chauffeur.vehiculeNom!,
                    color: const Color(0xFF3158B6),
                    background: const Color(0xFFEAF1FF),
                    icon: Icons.directions_car_outlined,
                  ),
                if (day.isServiceDay)
                  _MiniBadge(
                    label: ChauffeurProgrammeCalculator.timeRange(programme),
                    color: const Color(0xFF2C3650),
                    background: const Color(0xFFF1F4FA),
                    icon: Icons.schedule_rounded,
                  ),
                if (day.isSalaryDay)
                  const _MiniBadge(
                    label: 'Versement attendu',
                    color: Color(0xFF7B4B00),
                    background: Color(0xFFFFF4DE),
                    icon: Icons.payments_outlined,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  String _initials(Chauffeur c) {
    final p = c.prenom.isNotEmpty ? c.prenom[0] : '';
    final n = c.nom.isNotEmpty ? c.nom[0] : '';
    return (p + n).toUpperCase();
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  bool _isSameDate(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class ChauffeurProgrammeCalculator {
  static String timeRange(ProgrammeTravail programme) {
    String formatTime(TimeOfDay value) {
      final hh = value.hour.toString().padLeft(2, '0');
      final mm = value.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    return '${formatTime(programme.heureDebutService)} - ${formatTime(programme.heureFinService)}';
  }

  /// Vrai si [chauffeur] conduit (service) à [date] selon le programme.
  /// Réutilisé par la validation du formulaire d'indisponibilité.
  static bool travaille(
    ProgrammeTravail programme,
    ProgrammeChauffeur chauffeur,
    DateTime date,
  ) =>
      scheduleForDate(programme, chauffeur, date) != null;

  static DateTime? initialSelectedDate(
    ProgrammeTravail programme,
    ProgrammeChauffeur chauffeur,
  ) {
    final today = _dateOnly(DateTime.now());
    if (scheduleForDate(programme, chauffeur, today) != null) {
      return today;
    }

    for (int offset = 1; offset <= 120; offset++) {
      final next = today.add(Duration(days: offset));
      if (scheduleForDate(programme, chauffeur, next) != null) {
        return next;
      }
    }

    for (int offset = 1; offset <= 60; offset++) {
      final previous = today.subtract(Duration(days: offset));
      if (scheduleForDate(programme, chauffeur, previous) != null) {
        return previous;
      }
    }

    return null;
  }

  static ChauffeurProgrammeDay? scheduleForDate(
    ProgrammeTravail programme,
    ProgrammeChauffeur chauffeur,
    DateTime date,
  ) {
    if (chauffeur.dateService != null &&
        _dateOnly(date).isBefore(_dateOnly(chauffeur.dateService!))) {
      return null;
    }

    final serviceDriver = _serviceDriverForDate(programme, _dateOnly(date));
    final salaryDriver = _salaryDriverForDate(programme, _dateOnly(date));
    final isServiceDay = serviceDriver?.chauffeurId == chauffeur.chauffeurId;
    final isSalaryDay = salaryDriver?.chauffeurId == chauffeur.chauffeurId;

    if (!isServiceDay && !isSalaryDay) {
      return null;
    }

    return ChauffeurProgrammeDay(
      date: _dateOnly(date),
      isServiceDay: isServiceDay,
      isSalaryDay: isSalaryDay,
    );
  }

  static ProgrammeChauffeur? _serviceDriverForDate(
    ProgrammeTravail programme,
    DateTime date,
  ) {
    if (programme.chauffeurs.isEmpty || !_isWorkingDay(programme, date)) {
      return null;
    }

    final chauffeurs = [...programme.chauffeursTriesAlternance];
    final readyDrivers = chauffeurs
        .where(
          (chauffeur) =>
              chauffeur.dateService == null ||
              !date.isBefore(_dateOnly(chauffeur.dateService!)),
        )
        .toList();
    if (readyDrivers.isEmpty) {
      return null;
    }

    if (readyDrivers.length == 1 ||
        programme.modeAlternance != ModeAlternance.automatique ||
        programme.joursAlternance == null ||
        programme.joursAlternance! < 1) {
      return readyDrivers.first;
    }

    final alternanceStart = _effectiveAlternanceStart(programme, readyDrivers);
    if (alternanceStart.isAfter(date)) {
      return readyDrivers.first;
    }

    final serviceDays = _countWorkingDaysInclusive(programme, alternanceStart, date);
    final slot = (serviceDays - 1) ~/ programme.joursAlternance!;
    return readyDrivers[slot % readyDrivers.length];
  }

  static ProgrammeChauffeur? _salaryDriverForDate(
    ProgrammeTravail programme,
    DateTime date,
  ) {
    if (!programme.jourSalaireActif ||
        programme.jourSalaire == null ||
        programme.chauffeurs.isEmpty ||
        date.weekday != programme.jourSalaire!.weekday) {
      return null;
    }

    final readyDrivers = [...programme.chauffeurs]
      ..sort((a, b) {
        final first = a.ordreJourSalaire ?? a.ordreAlternance;
        final second = b.ordreJourSalaire ?? b.ordreAlternance;
        return first.compareTo(second);
      });
    readyDrivers.removeWhere(
      (chauffeur) =>
          chauffeur.dateService != null &&
          date.isBefore(_dateOnly(chauffeur.dateService!)),
    );
    if (readyDrivers.isEmpty) {
      return null;
    }

    int occurrence = 0;
    for (int day = 1; day <= date.day; day++) {
      final current = DateTime(date.year, date.month, day);
      if (current.weekday == programme.jourSalaire!.weekday) {
        occurrence++;
      }
    }

    final index = (occurrence - 1) % readyDrivers.length;
    return readyDrivers[index];
  }

  static bool _isWorkingDay(ProgrammeTravail programme, DateTime date) {
    if (programme.joursAlternanceSemaine.isEmpty) {
      return true;
    }
    return programme.joursAlternanceSemaine
        .any((jour) => jour.weekday == date.weekday);
  }

  static int _countWorkingDaysInclusive(
    ProgrammeTravail programme,
    DateTime start,
    DateTime end,
  ) {
    int count = 0;
    var cursor = _dateOnly(start);
    final last = _dateOnly(end);
    while (!cursor.isAfter(last)) {
      if (_isWorkingDay(programme, cursor)) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  static DateTime _effectiveAlternanceStart(
    ProgrammeTravail programme,
    List<ProgrammeChauffeur> readyDrivers,
  ) {
    DateTime anchor = programme.dateDebutAlternance != null
        ? _dateOnly(programme.dateDebutAlternance!)
        : _dateOnly(
            readyDrivers
                .where((chauffeur) => chauffeur.dateService != null)
                .map((chauffeur) => chauffeur.dateService!)
                .fold(DateTime.now(), _earlierDate),
          );

    for (final chauffeur in readyDrivers) {
      if (chauffeur.dateService != null) {
        anchor = _laterDate(anchor, _dateOnly(chauffeur.dateService!));
      }
    }
    return anchor;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _earlierDate(DateTime first, DateTime second) =>
      first.isBefore(second) ? first : second;

  static DateTime _laterDate(DateTime first, DateTime second) =>
      first.isAfter(second) ? first : second;
}

class _ChauffeurCalendarCell {
  final DateTime date;
  final bool inMonth;
  final ChauffeurProgrammeDay? schedule;

  /// (a) Le chauffeur (titulaire) est indisponible ce jour-là : il ne travaille
  /// pas, il est remplacé. [remplacantNom] = qui le remplace.
  final bool indisponible;
  final String? remplacantNom;

  /// (b) Ce jour-là, le chauffeur remplace un titulaire indisponible et conduit
  /// son véhicule. [remplaceVehicule] = véhicule emprunté ; [remplaceTitulaireNom]
  /// = titulaire remplacé.
  final String? remplaceVehicule;
  final String? remplaceTitulaireNom;

  const _ChauffeurCalendarCell({
    required this.date,
    required this.inMonth,
    required this.schedule,
    this.indisponible = false,
    this.remplacantNom,
    this.remplaceVehicule,
    this.remplaceTitulaireNom,
  });

  bool get estRemplacant => remplaceVehicule != null;
}

class ChauffeurProgrammeDay {
  final DateTime date;
  final bool isServiceDay;
  final bool isSalaryDay;

  const ChauffeurProgrammeDay({
    required this.date,
    required this.isServiceDay,
    required this.isSalaryDay,
  });
}

class _DocumentsTab extends ConsumerWidget {
  final Chauffeur chauffeur;
  const _DocumentsTab({required this.chauffeur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = chauffeur.id;
    final docsAsync = id != null
        ? ref.watch(documentsByChauffeurIdProvider(id))
        : const AsyncValue<List<DocumentChauffeurLocal>>.data([]);

    return docsAsync.when(
      loading: () => _buildContent(context, [], loading: true),
      error: (_, __) => _buildContent(context, []),
      data: (docs) => _buildContent(context, docs),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<DocumentChauffeurLocal> docs, {
    bool loading = false,
  }) {
    final allDocs = docs.where((d) {
      final nom = d.typeNom?.toLowerCase() ?? '';
      return nom != "photo d'identité";
    }).toList();

    if (allDocs.isEmpty && !loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            const Text(
              'Aucun document enregistré',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aucun document pour ce chauffeur.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (allDocs.isNotEmpty) ...[
          _sectionLabel('Documents'),
          const SizedBox(height: 8),
          ...allDocs.map((d) {
            final hasFile =
                d.fichierUrl != null && d.fichierUrl!.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: hasFile
                      ? () => showDialog(
                            context: context,
                            barrierColor:
                                Colors.black.withValues(alpha: 0.85),
                            builder: (_) => _DocViewerDialog(doc: d),
                          )
                      : null,
                  child: _RegularDocCard(doc: d),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  static Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7794),
          letterSpacing: 0.3,
        ),
      );
}

// ── Carte document régulier ──────────────────────────────────────────────────

class _RegularDocCard extends StatelessWidget {
  final DocumentChauffeurLocal doc;
  const _RegularDocCard({required this.doc});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isExpired = doc.statut == 'EXPIRE';
    final accentColor =
        isExpired ? const Color(0xFFC62828) : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpired ? Colors.red.shade200 : const Color(0xFFE4E9F5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 74,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                bottomLeft: Radius.circular(13),
              ),
            ),
            child: Icon(Icons.description_outlined,
                color: accentColor, size: 24),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (doc.dateEmission != null || doc.dateExpiration != null)
                    Row(
                      children: [
                        if (doc.dateEmission != null) ...[
                          Icon(Icons.calendar_today_outlined,
                              size: 11, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Ém. ${_fmt(doc.dateEmission!)}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (doc.dateExpiration != null) ...[
                          Icon(Icons.event_busy_outlined,
                              size: 11,
                              color: isExpired
                                  ? Colors.red.shade400
                                  : Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(
                            'Exp. ${_fmt(doc.dateExpiration!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isExpired
                                  ? Colors.red.shade400
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (doc.fichierNom != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.attach_file,
                            size: 11, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            doc.fichierNom!,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (doc.fichierUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.visibility_outlined,
                  size: 18, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }
}

// ── Viewer document régulier ─────────────────────────────────────────────────

class _DocViewerDialog extends ConsumerStatefulWidget {
  final DocumentChauffeurLocal doc;
  const _DocViewerDialog({required this.doc});

  @override
  ConsumerState<_DocViewerDialog> createState() => _DocViewerDialogState();
}

class _DocViewerDialogState extends ConsumerState<_DocViewerDialog> {
  late Future<Uint8List> _bytesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final client = ref.read(docChauffeurApiClientProvider);
    _bytesFuture = client.getBytes(widget.doc.fichierUrl!);
  }

  void _retry() => setState(_load);

  static bool _isBytesImage(Uint8List b) {
    if (b.length < 4) return false;
    if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
    if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true;
    if (b[0] == 0x42 && b[1] == 0x4D) return true;
    return false;
  }

  static bool _isBytesPdf(Uint8List b) =>
      b.length >= 4 &&
      b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46;

  bool get _fileIsPdf {
    final ft = widget.doc.fichierType ?? '';
    if (ft.contains('pdf')) return true;
    return (widget.doc.fichierNom ?? '').toLowerCase().endsWith('.pdf');
  }

  bool get _fileIsImage {
    final ft = widget.doc.fichierType ?? '';
    if (ft.startsWith('image/')) return true;
    final ext = (widget.doc.fichierNom ?? '').split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF1A1A2E),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.doc.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close,
                          color: Colors.white60, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
              SizedBox(
                height: 380,
                child: FutureBuilder<Uint8List>(
                  future: _bytesFuture,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white54, strokeWidth: 2),
                      );
                    }
                    if (snap.hasError || !snap.hasData) {
                      return _PermisViewerError(
                        message: snap.error?.toString(),
                        onRetry: _retry,
                      );
                    }
                    final bytes = snap.data!;
                    final isPdf = _isBytesPdf(bytes) || _fileIsPdf;
                    final isImage =
                        !isPdf && (_isBytesImage(bytes) || _fileIsImage);
                    if (!isPdf && !isImage) {
                      return _PermisNoPreview(
                        fichierType: widget.doc.fichierType,
                        fichierNom: widget.doc.fichierNom,
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: isPdf
                            ? _PermisPdfViewer(bytes: bytes)
                            : InteractiveViewer(
                                minScale: 0.5,
                                maxScale: 5.0,
                                child: Image.memory(bytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const _PermisViewerError()),
                              ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermisPdfViewer extends StatefulWidget {
  final Uint8List bytes;
  const _PermisPdfViewer({required this.bytes});

  @override
  State<_PermisPdfViewer> createState() => _PermisPdfViewerState();
}

class _PermisPdfViewerState extends State<_PermisPdfViewer> {
  PdfController? _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initPdf();
  }

  Future<void> _initPdf() async {
    try {
      final doc = await PdfDocument.openData(widget.bytes);
      if (!mounted) return;
      setState(() {
        _controller = PdfController(document: Future.value(doc));
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = true; _loading = false; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
      );
    }
    if (_error || _controller == null) return const _PermisViewerError();
    return PdfView(
      controller: _controller!,
      scrollDirection: Axis.vertical,
      pageSnapping: false,
      backgroundDecoration: const BoxDecoration(color: Color(0xFF12122A)),
    );
  }
}

class _PermisNoPreview extends StatelessWidget {
  final String? fichierType;
  final String? fichierNom;
  const _PermisNoPreview({this.fichierType, this.fichierNom});

  @override
  Widget build(BuildContext context) {
    final ft = fichierType ?? '';
    final icon = ft.contains('pdf')
        ? Icons.picture_as_pdf_outlined
        : Icons.description_outlined;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          const Text('Prévisualisation non disponible',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          if (fichierNom != null && fichierNom!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(fichierNom!,
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _PermisViewerError extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const _PermisViewerError({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined,
              color: Colors.white24, size: 64),
          const SizedBox(height: 12),
          const Text('Impossible de charger le fichier',
              style: TextStyle(color: Colors.white38, fontSize: 13)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white24, fontSize: 11),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh,
                  color: Colors.white54, size: 18),
              label: const Text('Réessayer',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Widgets partagés ─────────────────────────────────────────────────────────

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: Colors.grey)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.children,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E9F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final IconData? icon;

  const _InfoRow({required this.label, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final hasValue = value?.isNotEmpty ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: Colors.grey.shade500),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              hasValue ? value! : '—',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: hasValue ? FontWeight.w700 : FontWeight.normal,
                fontSize: 14,
                color: hasValue ? const Color(0xFF1A1A2E) : Colors.grey.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar partagé (miniature photo ou initiales) ────────────────────────────

/// Avatar d'un chauffeur. Si [hasPhoto] et [chauffeurId] sont fournis, charge
/// la miniature via `GET /chauffeurs/{id}/photo?v={version}` avec le Bearer
/// token ; sinon affiche un fallback avec les initiales.
///
/// Le paramètre `?v=` est géré par [chauffeurPhotoVersionProvider] et permet
/// de casser le cache réseau dès qu'une nouvelle photo est uploadée.
class ChauffeurAvatar extends ConsumerStatefulWidget {
  final int? chauffeurId;
  final String initials;
  final bool hasPhoto;
  final double size;

  const ChauffeurAvatar({
    super.key,
    required this.chauffeurId,
    required this.initials,
    required this.hasPhoto,
    this.size = 56,
  });

  @override
  ConsumerState<ChauffeurAvatar> createState() => _ChauffeurAvatarState();
}

class _ChauffeurAvatarState extends ConsumerState<ChauffeurAvatar> {
  Future<Map<String, String>?>? _headersFuture;

  @override
  void initState() {
    super.initState();
    if (widget.chauffeurId != null) {
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
    final id = widget.chauffeurId;
    final versions = ref.watch(chauffeurPhotoVersionProvider);
    final version = id != null ? (versions[id] ?? 0) : 0;

    final shouldLoadPhoto = widget.hasPhoto && id != null;

    final radius = BorderRadius.circular(widget.size * 0.25);

    Widget fallback() => Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: const Color(0xFFE8ECF8),
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.initials,
            style: TextStyle(
              fontSize: widget.size * 0.35,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        );

    if (!shouldLoadPhoto) return fallback();

    // ?v=X casse le cache réseau dès que la version change.
    final url = '${ApiConfig.baseUrl}/chauffeurs/$id/photo?v=$version';

    return FutureBuilder<Map<String, String>?>(
      future: _headersFuture,
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) return fallback();
        final headers = snap.data;
        if (headers == null) return fallback();
        return ClipRRect(
          borderRadius: radius,
          child: Image.network(
            url,
            key: ValueKey('$id-$version'),
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            headers: headers,
            errorBuilder: (_, __, ___) => fallback(),
            loadingBuilder: (ctx, child, progress) =>
                progress == null ? child : fallback(),
          ),
        );
      },
    );
  }
}

/// Prévisualisation plein écran de la photo d'un chauffeur.
/// Utilise [photoBase64] si disponible (déjà chargé depuis le détail),
/// sinon charge depuis le réseau avec le Bearer token.
class _PhotoFullscreenViewer extends StatefulWidget {
  final int? chauffeurId;
  final String? photoBase64;

  const _PhotoFullscreenViewer({this.chauffeurId, this.photoBase64});

  @override
  State<_PhotoFullscreenViewer> createState() => _PhotoFullscreenViewerState();
}

class _PhotoFullscreenViewerState extends State<_PhotoFullscreenViewer> {
  Future<Map<String, String>?>? _headersFuture;

  @override
  void initState() {
    super.initState();
    if (widget.photoBase64 == null && widget.chauffeurId != null) {
      _headersFuture = _loadHeaders();
    }
  }

  Future<Map<String, String>?> _loadHeaders() async {
    final token = await const SecureStorage().getAccessToken();
    if (token == null || token.isEmpty) return null;
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Widget build(BuildContext context) {
    final Widget photo;
    if (widget.photoBase64 != null) {
      photo = Image.memory(
        base64Decode(widget.photoBase64!),
        fit: BoxFit.cover,
      );
    } else {
      photo = FutureBuilder<Map<String, String>?>(
        future: _headersFuture,
        builder: (_, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 200,
              child:
                  Center(child: CircularProgressIndicator(color: Colors.white)),
            );
          }
          final headers = snap.data;
          if (headers == null || widget.chauffeurId == null) {
            return const SizedBox(
              height: 200,
              child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 64)),
            );
          }
          return Image.network(
            '${ApiConfig.baseUrl}/chauffeurs/${widget.chauffeurId}/photo',
            fit: BoxFit.cover,
            headers: headers,
            errorBuilder: (_, __, ___) => const SizedBox(
              height: 200,
              child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: Colors.white54, size: 64)),
            ),
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 200,
                    child: Center(
                        child:
                            CircularProgressIndicator(color: Colors.white))),
          );
        },
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                photo,
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
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
