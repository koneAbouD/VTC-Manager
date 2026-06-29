import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../../domain/enums/type_chauffeur.dart';
import '../providers/chauffeur_provider.dart';
import '../providers/chauffeur_state.dart';
import '../pages/chauffeur_detail_page.dart';
import 'chauffeur_form_page.dart';

// ── Toast helper ─────────────────────────────────────────────────────────────

enum _ToastType { success, error, warning, info }

void _appToast(
  BuildContext context,
  String message, {
  _ToastType type = _ToastType.success,
  Duration? duration,
}) {
  final (Color bg, IconData icon) = switch (type) {
    _ToastType.success => (const Color(0xFF1B5E20), Icons.check_circle_outline_rounded),
    _ToastType.error   => (const Color(0xFFB71C1C), Icons.error_outline_rounded),
    _ToastType.warning => (const Color(0xFFE65100), Icons.warning_amber_rounded),
    _ToastType.info    => (const Color(0xFF1A237E), Icons.info_outline_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ??
          (type == _ToastType.error || type == _ToastType.warning
              ? const Duration(seconds: 4)
              : const Duration(seconds: 2)),
    ));
}

// ── Palettes statut ──────────────────────────────────────────────────────────

Color _statutColor(ChauffeurStatus? s) => switch (s) {
      ChauffeurStatus.actif => const Color(0xFF2E7D32),
      ChauffeurStatus.enService => const Color(0xFF1565C0),
      ChauffeurStatus.inactif => Colors.grey,
      ChauffeurStatus.enConge => const Color(0xFFE65100),
      ChauffeurStatus.suspendu => const Color(0xFFC62828),
      null => Colors.grey,
    };

// ── Page principale ──────────────────────────────────────────────────────────

class ChauffeursPage extends ConsumerStatefulWidget {
  const ChauffeursPage({super.key});

  @override
  ConsumerState<ChauffeursPage> createState() => _ChauffeursPageState();
}

class _ChauffeursPageState extends ConsumerState<ChauffeursPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _query = '';
  ChauffeurStatus? _statutFilter;
  bool _headerVisible = true;
  double _lastScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs(),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer le chauffeur'),
        content: Text('Supprimer $name définitivement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error =
        await ref.read(chauffeurNotifierProvider.notifier).deleteChauffeur(id);
    if (mounted && error != null) {
      _appToast(context, error, type: _ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chauffeurNotifierProvider);

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
            MaterialPageRoute(builder: (_) => const ChauffeurFormPage()),
          );
          if (mounted) {
            ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs();
          }
        },
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Ajouter un chauffeur'),
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
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Nom, téléphone, véhicule…',
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
              child: DropdownButton<ChauffeurStatus?>(
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
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tous')),
                  DropdownMenuItem(
                      value: ChauffeurStatus.actif, child: Text('Actif')),
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
                onChanged: (v) => setState(() => _statutFilter = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ChauffeurState state) {
    return switch (state) {
      ChauffeurLoading() => const _SkeletonList(),
      ChauffeurError(:final message) => _ErrorState(
          message: message,
          onRetry: () =>
              ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs(),
        ),
      ChauffeurLoaded(:final chauffeurs) ||
      ChauffeurActionSuccess(:final chauffeurs) =>
        _buildList(chauffeurs),
      _ => const _SkeletonList(),
    };
  }

  Widget _buildList(List<Chauffeur> all) {
    final chauffeurs = _filter(all);

    if (all.isEmpty) {
      return _EmptyState(
        onAdd: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChauffeurFormPage()),
          );
          if (mounted) {
            ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs();
          }
        },
      );
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Text(
            '${chauffeurs.length} résultat${chauffeurs.length > 1 ? 's' : ''}',
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
                ref.read(chauffeurNotifierProvider.notifier).loadChauffeurs(),
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
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
                  onEdit: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChauffeurFormPage(initial: c)),
                    );
                    if (mounted) {
                      ref
                          .read(chauffeurNotifierProvider.notifier)
                          .loadChauffeurs();
                    }
                  },
                  onDelete: () => _confirmDelete(c.id!, c.displayName),
                );
              },
            ),
          ),
        ),
      ],
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
    final theme = Theme.of(context);
    final statusColor = _statutColor(chauffeur.statut);
    final initials =
        '${chauffeur.prenom.isNotEmpty ? chauffeur.prenom[0] : ''}'
                '${chauffeur.nom.isNotEmpty ? chauffeur.nom[0] : ''}'
            .toUpperCase();

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
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          _Avatar(
                            chauffeurId: chauffeur.id,
                            initials: initials,
                            hasPhoto: chauffeur.photoUrl != null &&
                                chauffeur.photoUrl!.isNotEmpty,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        chauffeur.displayName,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (chauffeur.type != null) ...[
                                      const SizedBox(width: 6),
                                      _TypeBadge(type: chauffeur.type!),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                _StatusChip(
                                  label: chauffeur.statut?.label ?? 'Inconnu',
                                  color: statusColor,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    if (chauffeur.telephone != null)
                                      _MetaRow(
                                        icon: Icons.phone_outlined,
                                        label: chauffeur.telephone!,
                                      ),
                                    if (chauffeur.vehiculeNom != null &&
                                        chauffeur.vehiculeNom!.isNotEmpty)
                                      _MetaRow(
                                        icon: Icons.directions_car_outlined,
                                        label: chauffeur.vehiculeNom!,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert_rounded,
                                color: Colors.grey.shade400, size: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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

// ── Avatar ───────────────────────────────────────────────────────────────────

class _Avatar extends ConsumerWidget {
  final int? chauffeurId;
  final String initials;
  final bool hasPhoto;

  const _Avatar({
    required this.chauffeurId,
    required this.initials,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Même rendu que ChauffeurDetailPage : fallback initiales « lite »
    // (fond clair + texte couleur primaire) géré par ChauffeurAvatar.
    return ChauffeurAvatar(
      chauffeurId: chauffeurId,
      initials: initials,
      hasPhoto: hasPhoto,
      size: 52,
    );
  }
}

// ── Petits widgets ───────────────────────────────────────────────────────────

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
      child: Text(
        type.label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                    child: Row(children: [
                      _Bone(w: 52, h: 52, r: 14, opacity: _anim.value),
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
                              _Bone(w: 90, h: 10, opacity: _anim.value),
                              const SizedBox(width: 10),
                              _Bone(w: 80, h: 10, opacity: _anim.value),
                            ]),
                          ],
                        ),
                      ),
                    ]),
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
  final double w, h, r, opacity;
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
              child:
                  Icon(Icons.people_outline_rounded, size: 36, color: color),
            ),
            const SizedBox(height: 20),
            Text('Aucun chauffeur',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Ajoutez votre premier chauffeur à la flotte.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Ajouter un chauffeur'),
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
