import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import 'condition_travail_models.dart';
import 'condition_travail_wizard_page.dart';

export 'condition_travail_models.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _ctSecureStorageProvider =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _ctApiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_ctSecureStorageProvider)));

// autoDispose : la liste est rechargée à chaque ouverture du sélecteur, donc
// toujours à jour après une création/modification faite ailleurs (liste, fiche
// détail…), sans cache périmé inter-écrans.
final _conditionsTravailProvider =
    FutureProvider.autoDispose<List<ConditionTravailLocal>>((ref) async {
  final client = ref.watch(_ctApiClientProvider);
  final response = await client.get('/conditions-travail');
  return (response as List)
      .map((e) => ConditionTravailLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Page ──────────────────────────────────────────────────────────────────────

class ConditionTravailSelectorPage extends ConsumerStatefulWidget {
  const ConditionTravailSelectorPage({super.key});

  @override
  ConsumerState<ConditionTravailSelectorPage> createState() =>
      _ConditionTravailSelectorPageState();
}

class _ConditionTravailSelectorPageState
    extends ConsumerState<ConditionTravailSelectorPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_conditionsTravailProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(async),
            _buildSearchBar(),
            Expanded(
              child: async.when(
                loading: _buildLoading,
                error: (e, _) => _buildError(e),
                data: (conditions) => _buildList(conditions),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AsyncValue<List<ConditionTravailLocal>> async) {
    return Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Conditions de travail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sélectionner une condition de travail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openWizard,
            child: Container(
              width: 56,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.add_rounded,
                  size: 20, color: Color(0xFF1A1A2E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Rechercher par nom…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: Colors.grey.shade500, size: 18),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF43A047), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  Widget _buildError(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: Color(0xFFE53935), size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger les données',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Vérifiez votre connexion et réessayez.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () => ref.refresh(_conditionsTravailProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF43A047),
                side: const BorderSide(color: Color(0xFF43A047)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<ConditionTravailLocal> conditions) {
    final filtered = _query.isEmpty
        ? conditions
        : conditions
            .where((ct) =>
                ct.nom.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(conditions.isEmpty);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ConditionCard(
        condition: filtered[i],
        onTap: () => Navigator.pop(context, filtered[i]),
      ),
    );
  }

  Widget _buildEmptyState(bool noData) {
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
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                noData
                    ? Icons.work_outline_rounded
                    : Icons.search_off_rounded,
                color: const Color(0xFF43A047),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              noData ? 'Aucune condition de travail' : 'Aucun résultat',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              noData
                  ? 'Commencez par créer votre première\ncondition de travail.'
                  : 'Aucune condition ne correspond\nà « $_query ».',
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (noData) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openWizard,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer une condition'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF43A047),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Future<void> _openWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConditionTravailWizardPage()),
    );
    if (!mounted) return;
    ref.invalidate(_conditionsTravailProvider);
  }
}

// ── Carte condition de travail ─────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final ConditionTravailLocal condition;
  final VoidCallback onTap;

  const _ConditionCard({required this.condition, required this.onTap});

  static const _programmeColors = {
    'JOURNALIER': Color(0xFF43A047),
    'HEBDOMADAIRE': Color(0xFF7950F2),
  };

  static const _programmeLabels = {
    'JOURNALIER': 'Journalier',
    'HEBDOMADAIRE': 'Hebdomadaire',
  };

  static const _alternanceLabels = {
    'AUTOMATIQUE': 'Auto',
    'MANUELLE': 'Manuel',
  };

  Color get _programmeColor =>
      _programmeColors[condition.typeProgramme] ?? const Color(0xFF43A047);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête coloré ────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _programmeColor.withOpacity(0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        condition.nom,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      label: _programmeLabels[condition.typeProgramme] ??
                          condition.typeProgramme,
                      color: _programmeColor,
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.grey.shade400, size: 20),
                  ],
                ),
              ),
              // ── Corps ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ligne 1 : métriques principales
                    Row(
                      children: [
                        _MetricChip(
                          icon: Icons.people_outline_rounded,
                          label:
                              '${condition.nbChauffeurs} chauffeur${condition.nbChauffeurs > 1 ? 's' : ''}',
                        ),
                        const SizedBox(width: 8),
                        _MetricChip(
                          icon: Icons.monetization_on_outlined,
                          label:
                              '${condition.objectifRecette.toStringAsFixed(0)} XOF',
                          highlight: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Ligne 2 : horaires
                    Row(
                      children: [
                        _InfoRow(
                          icon: Icons.schedule_rounded,
                          label:
                              '${condition.heureDebut} – ${condition.heureFin}',
                        ),
                        const SizedBox(width: 16),
                        _InfoRow(
                          icon: Icons.payments_outlined,
                          label: 'Versement à ${condition.heureVersement}',
                        ),
                      ],
                    ),
                    // Ligne 3 : alternance + jour salaire
                    if (condition.nbChauffeurs == 2 ||
                        condition.jourSalaire.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (condition.nbChauffeurs == 2)
                            _InfoRow(
                              icon: Icons.sync_alt_rounded,
                              label:
                                  '${_alternanceLabels[condition.modeAlternance] ?? condition.modeAlternance}'
                                  ' · ${condition.joursAlternance}j',
                            ),
                          if (condition.nbChauffeurs == 2 &&
                              condition.jourSalaire.isNotEmpty)
                            const SizedBox(width: 16),
                          if (condition.jourSalaire.isNotEmpty)
                            _InfoRow(
                              icon: Icons.event_available_rounded,
                              label: 'Salaire le ${_capitalize(condition.jourSalaire)}',
                            ),
                        ],
                      ),
                    ],
                    // Ligne 4 : compteurs cotisations + pénalités
                    if (condition.cotisations.isNotEmpty ||
                        condition.penalites.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFF0F0F0)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (condition.cotisations.isNotEmpty) ...[
                            _CountBadge(
                              icon: Icons.savings_outlined,
                              count: condition.cotisations.length,
                              label: 'cotisation${condition.cotisations.length > 1 ? 's' : ''}',
                              color: const Color(0xFF43A047),
                            ),
                            if (condition.penalites.isNotEmpty)
                              const SizedBox(width: 12),
                          ],
                          if (condition.penalites.isNotEmpty)
                            _CountBadge(
                              icon: Icons.gavel_rounded,
                              count: condition.penalites.length,
                              label: 'sanction${condition.penalites.length > 1 ? 's' : ''}',
                              color: const Color(0xFFC62828),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _MetricChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        highlight ? const Color(0xFF1B5E20) : Colors.grey.shade700;
    final bg = highlight
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFF5F5F5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

class _CountBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _CountBadge({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '$count $label',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Skeleton card (chargement) ─────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _Shimmer(width: 140, height: 14, radius: 7),
                const Spacer(),
                _Shimmer(width: 70, height: 22, radius: 11),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _Shimmer(width: 90, height: 28, radius: 8),
                  const SizedBox(width: 8),
                  _Shimmer(width: 110, height: 28, radius: 8),
                ]),
                const SizedBox(height: 10),
                _Shimmer(width: 200, height: 12, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Shimmer(
      {required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
