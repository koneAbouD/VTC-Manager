import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import 'condition_travail_models.dart';
import 'condition_travail_detail_page.dart';
import 'condition_travail_wizard_page.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _listeSecureStorageProvider =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _listeApiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(_listeSecureStorageProvider)));

final conditionsTravailListeProvider =
    FutureProvider<List<ConditionTravailLocal>>((ref) async {
  final client = ref.watch(_listeApiClientProvider);
  final response = await client.get('/conditions-travail');
  return (response as List)
      .map((e) => ConditionTravailLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Constantes de design ──────────────────────────────────────────────────────

const _kPrimary = Color(0xFF43A047);
const _kDark = Color(0xFF1A1A2E);

class _ProgrammeStyle {
  final Color accent;
  final Color bg;
  final Color text;
  final IconData icon;
  final String label;

  const _ProgrammeStyle({
    required this.accent,
    required this.bg,
    required this.text,
    required this.icon,
    required this.label,
  });
}

const _programmeStyles = <String, _ProgrammeStyle>{
  'JOURNALIER': _ProgrammeStyle(
    accent: Color(0xFF43A047),
    bg: Color(0xFFE3F0FF),
    text: Color(0xFF43A047),
    icon: Icons.wb_sunny_rounded,
    label: 'Journalier',
  ),
  'HEBDOMADAIRE': _ProgrammeStyle(
    accent: Color(0xFF00695C),
    bg: Color(0xFFE0F2F1),
    text: Color(0xFF00695C),
    icon: Icons.date_range_rounded,
    label: 'Hebdomadaire',
  ),
};

_ProgrammeStyle _styleOf(String prog) =>
    _programmeStyles[prog] ??
    const _ProgrammeStyle(
      accent: _kPrimary,
      bg: Color(0xFFE3F0FF),
      text: _kPrimary,
      icon: Icons.settings_rounded,
      label: 'Autre',
    );

// ── Page ─────────────────────────────────────────────────────────────────────

class ConditionTravailListePage extends ConsumerStatefulWidget {
  const ConditionTravailListePage({super.key});

  @override
  ConsumerState<ConditionTravailListePage> createState() =>
      _ConditionTravailListePageState();
}

class _ConditionTravailListePageState
    extends ConsumerState<ConditionTravailListePage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _search = '';
  bool _searchVisible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    final offset = _scrollCtrl.offset;
    final delta = offset - _lastOffset;
    _lastOffset = offset;
    if (offset <= 0) {
      if (!_searchVisible) setState(() => _searchVisible = true);
      return;
    }
    if (delta > 3 && _searchVisible) {
      setState(() => _searchVisible = false);
    } else if (delta < -3 && !_searchVisible) {
      setState(() => _searchVisible = true);
    }
  }

  List<ConditionTravailLocal> _applyFilters(
      List<ConditionTravailLocal> all) {
    final q = _search.toLowerCase().trim();
    if (q.isEmpty) return all;
    return all.where((c) => c.nom.toLowerCase().contains(q)).toList();
  }

  Future<void> _openWizard() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConditionTravailWizardPage()),
    );
    ref.invalidate(conditionsTravailListeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conditionsTravailListeProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(async),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              tween: Tween(begin: 1.0, end: _searchVisible ? 1.0 : 0.0),
              builder: (_, v, child) => ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: v,
                  child: Opacity(opacity: v, child: child),
                ),
              ),
              child: _buildSearchBar(),
            ),
            Expanded(child: _buildBody(async)),
          ],
        ),
      ),
    );
  }

  // ── En-tête ──────────────────────────────────────────────────────────────

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
                  size: 18, color: _kDark),
            ),
          ),
          const Expanded(
            child: Text(
              'Conditions de travail',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kDark,
                letterSpacing: -0.3,
              ),
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
                  size: 20, color: _kDark),
            ),
          ),
        ],
      ),
    );
  }

  // ── Barre de recherche ────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: const TextStyle(fontSize: 14, color: _kDark),
        decoration: InputDecoration(
          hintText: 'Rechercher une configuration…',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon:
              Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
          suffixIcon: _search.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.grey.shade400, size: 18),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF7F8FC),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFEEF0F5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kPrimary, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Corps ─────────────────────────────────────────────────────────────────

  Widget _buildBody(AsyncValue<List<ConditionTravailLocal>> async) {
    return async.when(
      loading: () => const _SkeletonList(),
      error: (e, _) => _ErrorState(
        message: e.toString(),
        onRetry: () => ref.invalidate(conditionsTravailListeProvider),
      ),
      data: (all) {
        final conditions = _applyFilters(all);
        if (all.isEmpty) {
          return _EmptyState(onAdd: _openWizard);
        }
        if (conditions.isEmpty) {
          return const _NoResultState();
        }
        return RefreshIndicator(
          color: _kPrimary,
          onRefresh: () async =>
              ref.invalidate(conditionsTravailListeProvider),
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: conditions.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ConditionCard(
                condition: conditions[i],
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ConditionTravailDetailPage(
                          condition: conditions[i]),
                    ),
                  );
                  ref.invalidate(conditionsTravailListeProvider);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Carte condition ───────────────────────────────────────────────────────────

class _ConditionCard extends StatelessWidget {
  final ConditionTravailLocal condition;
  final VoidCallback? onTap;

  const _ConditionCard({required this.condition, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = _styleOf(condition.typeProgramme);
    final totalCotis = condition.cotisations.fold<double>(
        0, (sum, c) => sum + c.montant);
    final nbPenalites = condition.penalites.length;
    final nbCotisations = condition.cotisations.length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contenu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ligne titre + badge programme
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              condition.nom,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: _kDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _ProgrammeBadge(style: style),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Ligne horaires + objectif
                      Row(
                        children: [
                          _MetaChip(
                            icon: Icons.access_time_rounded,
                            label:
                                '${condition.heureDebut} – ${condition.heureFin}',
                            color: style.accent,
                          ),
                          const SizedBox(width: 8),
                          _MetaChip(
                            icon: Icons.people_rounded,
                            label: '${condition.nbChauffeurs} chauffeur${condition.nbChauffeurs > 1 ? 's' : ''}',
                            color: style.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Objectif recette
                      _ObjectifBand(
                        typeRecette: condition.typeRecette,
                        montant: condition.objectifRecette,
                      ),
                      // Footer cotisations + pénalités
                      const SizedBox(height: 10),
                      _CardFooter(
                        nbCotisations: nbCotisations,
                        totalCotis: totalCotis,
                        nbPenalites: nbPenalites,
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

// ── Badge programme ───────────────────────────────────────────────────────────

class _ProgrammeBadge extends StatelessWidget {
  final _ProgrammeStyle style;
  const _ProgrammeBadge({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.text),
          const SizedBox(width: 4),
          Text(
            style.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: style.text,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

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
        Icon(icon, size: 13, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Bande objectif recette ────────────────────────────────────────────────────

class _ObjectifBand extends StatelessWidget {
  final String typeRecette;
  final double montant;
  const _ObjectifBand({required this.typeRecette, required this.montant});

  @override
  Widget build(BuildContext context) {
    final isReel = typeRecette == 'MONTANT_REEL';

    final bg = isReel ? const Color(0xFFFFF8E1) : const Color(0xFFE8F5E9);
    final color = isReel ? const Color(0xFFE65100) : const Color(0xFF43A047);
    final icon = isReel ? Icons.show_chart_rounded : Icons.trending_up_rounded;
    final label = isReel
        ? 'Recette réelle'
        : 'Objectif ${montant.toStringAsFixed(0)} XOF';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (isReel) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Variable',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Footer carte ──────────────────────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  final int nbCotisations;
  final double totalCotis;
  final int nbPenalites;
  const _CardFooter(
      {required this.nbCotisations,
      required this.totalCotis,
      required this.nbPenalites});

  @override
  Widget build(BuildContext context) {
    if (nbCotisations == 0 && nbPenalites == 0) {
      return Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 13, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text(
            'Aucune cotisation ni pénalité',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
          ),
        ],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        if (nbCotisations > 0)
          _FooterTag(
            icon: Icons.payments_outlined,
            label:
                '$nbCotisations cotisation${nbCotisations > 1 ? 's' : ''} · ${totalCotis.toStringAsFixed(0)} XOF',
            color: const Color(0xFF43A047),
            bg: const Color(0xFFE8F5E9),
          ),
        if (nbPenalites > 0)
          _FooterTag(
            icon: Icons.gavel_rounded,
            label:
                '$nbPenalites pénalité${nbPenalites > 1 ? 's' : ''}',
            color: const Color(0xFFE65100),
            bg: const Color(0xFFFFF3E0),
          ),
      ],
    );
  }
}

class _FooterTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  const _FooterTag(
      {required this.icon,
      required this.label,
      required this.color,
      required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: 5,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _SkeletonCard(),
      ),
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
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.85)
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Row(
            children: [
              _Bone(w: 5, h: 110, r: 0, opacity: _anim.value),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Bone(w: 140, h: 14, opacity: _anim.value),
                          _Bone(w: 70, h: 22, r: 20, opacity: _anim.value),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(children: [
                        _Bone(w: 100, h: 12, opacity: _anim.value),
                        const SizedBox(width: 8),
                        _Bone(w: 80, h: 12, opacity: _anim.value),
                      ]),
                      const SizedBox(height: 10),
                      _Bone(w: double.infinity, h: 30, r: 8, opacity: _anim.value),
                      const SizedBox(height: 10),
                      Row(children: [
                        _Bone(w: 110, h: 22, r: 6, opacity: _anim.value),
                        const SizedBox(width: 8),
                        _Bone(w: 80, h: 22, r: 6, opacity: _anim.value),
                      ]),
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

class _Bone extends StatelessWidget {
  final double w, h, r, opacity;
  const _Bone({required this.w, required this.h, this.r = 6, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: w == double.infinity ? null : w,
        height: h,
        decoration: BoxDecoration(
          color: Colors.grey.shade300.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(r),
        ),
      );
}

// ── États vide / no-result / erreur ──────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                  color: Color(0xFFE3F0FF), shape: BoxShape.circle),
              child: const Icon(Icons.shield_rounded,
                  size: 40, color: _kPrimary),
            ),
            const SizedBox(height: 20),
            const Text(
              'Aucune configuration',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _kDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez votre première condition de travail\npour l\'appliquer à vos véhicules.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Créer une configuration',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultState extends StatelessWidget {
  const _NoResultState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'Aucun résultat',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Text(
            'Essayez un autre filtre ou mot-clé.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
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
              decoration:
                  BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.cloud_off_rounded,
                  size: 32, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            const Text('Erreur de chargement',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16, color: _kDark)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: _kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
