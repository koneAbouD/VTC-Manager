import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage.dart';
import 'groupe_form_page.dart';
import 'groupe_models.dart';

export 'groupe_models.dart';

// ── Toast helpers ──────────────────────────────────────────────────────────────
enum _ToastType { success, error, warning, info }

void _appToast(BuildContext context, String message,
    {_ToastType type = _ToastType.success, Duration? duration}) {
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
        Expanded(child: Text(message,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white))),
      ]),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      duration: duration ?? (type == _ToastType.error || type == _ToastType.warning
          ? const Duration(seconds: 4) : const Duration(seconds: 2)),
    ));
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _gsSecureStorage =
    Provider<SecureStorage>((ref) => const SecureStorage());

final _gsApiClient =
    Provider<ApiClient>((ref) => ApiClient(ref.watch(_gsSecureStorage)));

final _groupesProvider = FutureProvider<List<GroupeLocal>>((ref) async {
  final client = ref.watch(_gsApiClient);
  final response = await client.get('/v1/groupes');
  return (response as List)
      .map((e) => GroupeLocal.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Palette d'avatars ─────────────────────────────────────────────────────────

const _avatarPalette = [
  Color(0xFF3B5BDB), // bleu indigo
  Color(0xFF7950F2), // violet
  Color(0xFF0CA678), // vert émeraude
  Color(0xFFE67700), // orange
  Color(0xFFC2255C), // rose foncé
  Color(0xFF1098AD), // cyan
  Color(0xFF2F9E44), // vert forêt
  Color(0xFFD6336C), // framboise
];

Color _avatarColor(String nom) {
  if (nom.isEmpty) return _avatarPalette[0];
  return _avatarPalette[nom.codeUnitAt(0) % _avatarPalette.length];
}

// ── Page ──────────────────────────────────────────────────────────────────────

class GroupeSelectorPage extends ConsumerStatefulWidget {
  const GroupeSelectorPage({super.key});

  @override
  ConsumerState<GroupeSelectorPage> createState() => _GroupeSelectorPageState();
}

class _GroupeSelectorPageState extends ConsumerState<GroupeSelectorPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _deletingId = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Interroge le backend pour savoir si le groupe est encore utilisé.
  /// Retourne `{utilise: bool, nbVehicules: int}` ou null en cas d'erreur.
  Future<Map<String, dynamic>?> _checkUtilisation(int groupeId) async {
    try {
      final client = ref.read(_gsApiClient);
      final res = await client.get('/v1/groupes/$groupeId/utilisation');
      return res as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openForm() async {
    final nav = Navigator.of(context);
    final result = await nav.push<GroupeLocal>(
      MaterialPageRoute(builder: (_) => const GroupeFormPage()),
    );
    if (!mounted) return;
    ref.invalidate(_groupesProvider);
    if (result != null) nav.pop(result);
  }

  Future<void> _deleteGroupe(GroupeLocal groupe) async {
    if (groupe.id == null || _deletingId) return;

    // ── Vérification en temps réel via l'API ──────────────────────────────
    setState(() => _deletingId = true);
    final utilisation = await _checkUtilisation(groupe.id!);
    if (!mounted) return;
    setState(() => _deletingId = false);

    if (utilisation == null) {
      _appToast(context, 'Impossible de vérifier l\'utilisation du groupe.',
          type: _ToastType.error);
      return;
    }

    final nbVehicules = (utilisation['nbVehicules'] as num?)?.toInt() ?? 0;
    final estUtilise = utilisation['utilise'] as bool? ?? nbVehicules > 0;

    // ── Groupe utilisé : alerte bloquante ──────────────────────────────────
    if (estUtilise) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3CD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE67700), size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Groupe utilisé',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.6),
              children: [
                const TextSpan(
                    text: 'Ce groupe est actuellement assigné à '),
                TextSpan(
                  text:
                      '$nbVehicules véhicule${nbVehicules > 1 ? 's' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                    text:
                        '.\n\nVeuillez d\'abord retirer ce groupe de tous les véhicules avant de le supprimer.'),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE67700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      return;
    }

    // ── Groupe libre : confirmation de suppression ─────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: Color(0xFFE53935), size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Supprimer le groupe',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'Supprimer « ${groupe.nom} » ?\n\nCette action est irréversible.',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black54,
              side: const BorderSide(color: Color(0xFFE4E7EC)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final client = ref.read(_gsApiClient);
      await client.delete('/v1/groupes/${groupe.id}');
      if (!mounted) return;
      ref.invalidate(_groupesProvider);
      _appToast(context, 'Groupe « ${groupe.nom} » supprimé.');
    } catch (e) {
      if (!mounted) return;
      _appToast(context, 'Erreur lors de la suppression : $e', type: _ToastType.error);
    }
  }

  // Hauteur approximative d'une carte + séparateur
  static const double _itemHeight = 94.0;
  // Hauteur de l'en-tête (padding 14+14 + contenu ~38px)
  static const double _headerHeight = 66.0;

  bool _needsSearchBar(List<GroupeLocal> groupes, double availableHeight) {
    const listPadding = 16.0;
    return listPadding + groupes.length * _itemHeight > availableHeight - _headerHeight;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_groupesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showSearch = async.maybeWhen(
              data: (groupes) => _needsSearchBar(groupes, constraints.maxHeight),
              orElse: () => false,
            );
            if (!showSearch && _query.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchCtrl.clear();
                if (mounted) setState(() => _query = '');
              });
            }
            return Column(
              children: [
                _buildHeader(async),
                if (showSearch) _buildSearchBar() else const SizedBox(height: 10),
                Expanded(
                  child: async.when(
                    loading: _buildLoading,
                    error: (e, _) => _buildError(),
                    data: (groupes) => _buildList(groupes),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── En-tête ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(AsyncValue<List<GroupeLocal>> async) {
    return Container(
      color: Colors.white,
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
                  'Groupes de véhicules',
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
                  'Sélectionner un groupe de véhicules',
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
            onTap: _openForm,
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

  // ── Barre de recherche ──────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Rechercher un groupe…',
          hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: Colors.grey.shade400, size: 20),
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
            borderSide:
                const BorderSide(color: Color(0xFF3B5BDB), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  // ── États ───────────────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const _SkeletonCard(),
    );
  }

  Widget _buildError() {
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
                  color: Color(0xFFE53935), size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Impossible de charger les groupes',
              style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
              onPressed: () => ref.invalidate(_groupesProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Réessayer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3B5BDB),
                side: const BorderSide(color: Color(0xFF3B5BDB)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<GroupeLocal> groupes) {
    final filtered = _query.isEmpty
        ? groupes
        : groupes
            .where((g) =>
                g.nom.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    if (groupes.isEmpty) return _buildEmptyState(noData: true);
    if (filtered.isEmpty) return _buildEmptyState(noData: false);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _GroupeCard(
        groupe: filtered[i],
        deleting: _deletingId,
        onDelete: () => _deleteGroupe(filtered[i]),
      ),
    );
  }

  Widget _buildEmptyState({required bool noData}) {
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
                color: const Color(0xFFEFF4FF),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(
                noData
                    ? Icons.group_work_outlined
                    : Icons.search_off_rounded,
                color: const Color(0xFF3B5BDB),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              noData ? 'Aucun groupe créé' : 'Aucun résultat',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              noData
                  ? 'Commencez par créer votre\npremier groupe de véhicules.'
                  : 'Aucun groupe ne correspond\nà « $_query ».',
              style:
                  TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (noData) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Créer un groupe'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3B5BDB),
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

  // ── Bouton bas ──────────────────────────────────────────────────────────────

}

// ── Carte groupe ───────────────────────────────────────────────────────────────

class _GroupeCard extends StatelessWidget {
  final GroupeLocal groupe;
  final VoidCallback onDelete;
  final bool deleting;
  const _GroupeCard({
    required this.groupe,
    required this.onDelete,
    this.deleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _avatarColor(groupe.nom);
    final initiales = _initiales(groupe.nom);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pop(context, groupe),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE4E7EC),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // ── Avatar ────────────────────────────────────────────────────
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initiales,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // ── Infos ─────────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom
                    Text(
                      groupe.nom,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Badge véhicules
                    if (groupe.nbVehicules > 0) ...[
                      const SizedBox(height: 6),
                      _VehiculesBadge(
                          count: groupe.nbVehicules, color: color),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // ── Supprimer ─────────────────────────────────────────────────
              GestureDetector(
                onTap: deleting ? null : onDelete,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: deleting
                      ? const Padding(
                          padding: EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Color(0xFF9AA0AE)),
                        )
                      : Icon(Icons.close_rounded,
                          color: Colors.grey.shade400, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initiales(String nom) {
    final words = nom.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return nom.substring(0, nom.length.clamp(1, 2)).toUpperCase();
  }
}

class _VehiculesBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _VehiculesBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$count véhicule${count > 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skeleton card ──────────────────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      padding: const EdgeInsets.all(16),
      child: const Row(
        children: [
          _Shimmer(width: 52, height: 52, radius: 26),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Shimmer(width: 130, height: 13, radius: 6),
                SizedBox(height: 8),
                _Shimmer(width: 90, height: 11, radius: 5),
              ],
            ),
          ),
          _Shimmer(width: 30, height: 30, radius: 15),
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
