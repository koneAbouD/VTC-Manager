import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_header.dart';
import '../../features/chauffeur/domain/entities/chauffeur.dart';
import '../../features/chauffeur/domain/enums/chauffeur_status.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_provider.dart';
import '../../features/chauffeur/presentation/providers/chauffeur_state.dart';

class IndisponibilitePage extends ConsumerStatefulWidget {
  const IndisponibilitePage({super.key});

  @override
  ConsumerState<IndisponibilitePage> createState() =>
      _IndisponibilitePageState();
}

class _IndisponibilitePageState extends ConsumerState<IndisponibilitePage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chauffeurNotifierProvider);

    final List<Chauffeur> allChauffeurs = switch (state) {
      ChauffeurLoaded(:final chauffeurs) => chauffeurs,
      ChauffeurActionSuccess(:final chauffeurs) => chauffeurs,
      _ => [],
    };

    final filtered = _query.isEmpty
        ? allChauffeurs
        : allChauffeurs
            .where((c) => c.displayName
                .toLowerCase()
                .contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Indisponibilités'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Sous-titre ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Touchez un chauffeur pour modifier son statut.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),

          // ── Barre de recherche ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un chauffeur…',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Liste ────────────────────────────────────────────────────────
          Expanded(
            child: state is ChauffeurLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            const Text('Aucun chauffeur trouvé',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(
                              'Ajoutez d\'abord des chauffeurs à la flotte.',
                              style: TextStyle(
                                  color: Colors.grey.shade500, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) =>
                            _ChauffeurStatusTile(chauffeur: filtered[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Tuile chauffeur ────────────────────────────────────────────────────────────

class _ChauffeurStatusTile extends ConsumerWidget {
  final Chauffeur chauffeur;
  const _ChauffeurStatusTile({required this.chauffeur});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = chauffeur.statut ?? ChauffeurStatus.actif;

    return GestureDetector(
      onTap: () => _showStatusPicker(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF0F2F8),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_outline_rounded,
                  size: 22, color: Colors.grey.shade500),
            ),
            const SizedBox(width: 12),
            // Infos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chauffeur.displayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF1A1A2E)),
                  ),
                  if (chauffeur.telephone != null &&
                      chauffeur.telephone!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      chauffeur.telephone!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            // Badge statut
            _StatusBadge(status: status),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête sheet
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0F2F8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      size: 22, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chauffeur.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Sélectionner un nouveau statut',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Options de statut
            ...ChauffeurStatus.values.map(
              (s) => _StatusOption(
                status: s,
                current: chauffeur.statut ?? ChauffeurStatus.actif,
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  if (s == chauffeur.statut) return;
                  final id = chauffeur.id;
                  if (id == null) return;

                  final err = await ref
                      .read(chauffeurNotifierProvider.notifier)
                      .updateChauffeur(
                        id,
                        chauffeur.copyWith(statut: s),
                      );

                  if (!context.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: Colors.red.shade700,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${chauffeur.displayName} → ${s.label}'),
                        backgroundColor: Colors.green.shade700,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option de statut (dans le bottom sheet) ────────────────────────────────────

class _StatusOption extends StatelessWidget {
  final ChauffeurStatus status;
  final ChauffeurStatus current;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = status == current;
    final (Color color, IconData icon) = switch (status) {
      ChauffeurStatus.actif => (
          const Color(0xFF2E7D32),
          Icons.check_circle_outline_rounded
        ),
      ChauffeurStatus.enConge => (
          const Color(0xFFE65100),
          Icons.beach_access_outlined
        ),
      ChauffeurStatus.suspendu => (
          const Color(0xFFC62828),
          Icons.block_outlined
        ),
      ChauffeurStatus.inactif => (
          const Color(0xFF616161),
          Icons.person_off_outlined
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.09)
              : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              status.label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: selected ? color : const Color(0xFF1A1A2E),
              ),
            ),
            if (selected) ...[
              const Spacer(),
              Icon(Icons.check_rounded, color: color, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Badge statut ───────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final ChauffeurStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = switch (status) {
      ChauffeurStatus.actif => (const Color(0xFF2E7D32), 'Actif'),
      ChauffeurStatus.enConge => (const Color(0xFFE65100), 'En congé'),
      ChauffeurStatus.suspendu => (const Color(0xFFC62828), 'Suspendu'),
      ChauffeurStatus.inactif => (const Color(0xFF616161), 'Inactif'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
