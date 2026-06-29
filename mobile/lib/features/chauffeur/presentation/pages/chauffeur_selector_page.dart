import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/chauffeur.dart';
import '../../domain/enums/chauffeur_status.dart';
import '../providers/chauffeur_provider.dart';
import '../providers/chauffeur_state.dart';
import '../../../../core/widgets/app_header.dart';

class ChauffeurSelectorPage extends ConsumerStatefulWidget {
  /// Statuts dont les chauffeurs sont affichés mais **non sélectionnables**
  /// (grisés). Ex. {suspendu} pour la configuration véhicule. Vide par défaut.
  final Set<ChauffeurStatus> nonSelectionnables;

  /// Si true, les chauffeurs déjà affectés à un véhicule (« actifs » sur un
  /// véhicule) sont affichés mais non sélectionnables, avec l'immatriculation.
  final bool bloquerDejaAffectes;

  /// Véhicule en cours de configuration : un chauffeur déjà affecté à CE
  /// véhicule reste sélectionnable (seul l'affecté à un autre véhicule est bloqué).
  final int? vehiculeAutoriseId;

  const ChauffeurSelectorPage({
    super.key,
    this.nonSelectionnables = const {},
    this.bloquerDejaAffectes = false,
    this.vehiculeAutoriseId,
  });

  @override
  ConsumerState<ChauffeurSelectorPage> createState() =>
      _ChauffeurSelectorPageState();
}

class _ChauffeurSelectorPageState
    extends ConsumerState<ChauffeurSelectorPage> {
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
            .where((c) =>
                c.displayName
                    .toLowerCase()
                    .contains(_query.toLowerCase()) ||
                (c.telephone ?? '')
                    .toLowerCase()
                    .contains(_query.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const AppHeader(title: 'Sélectionner un chauffeur'),
      body: Column(
        children: [
          // ── Barre de recherche ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un chauffeur...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),

          // ── Liste ───────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_off_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Aucun chauffeur trouvé',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Aucun chauffeur disponible',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      final affecteAilleurs = widget.bloquerDejaAffectes &&
                          c.vehiculeId != null &&
                          c.vehiculeId != widget.vehiculeAutoriseId;
                      final bloque =
                          widget.nonSelectionnables.contains(c.statut) ||
                              affecteAilleurs;
                      // Sous-ligne : téléphone, ou motif de non-sélection daté.
                      final String? sousTitre = bloque
                          ? _motifNonSelectionnable(c)
                          : (c.telephone != null && c.telephone!.isNotEmpty
                              ? c.telephone
                              : null);
                      return Opacity(
                        opacity: bloque ? 0.55 : 1,
                        child: GestureDetector(
                          onTap: () => bloque
                              ? _avertirNonSelectionnable(c)
                              : Navigator.pop(context, c),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE4E7EC)),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 22, color: Colors.grey.shade400),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${c.prenom} ${c.nom}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                      ),
                                      if (sousTitre != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          sousTitre,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: bloque
                                                ? const Color(0xFFC62828)
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatutPill(statut: c.statut),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

        ],
      ),
    );
  }

  /// Motif (daté/contextuel) pour lequel un chauffeur ne peut pas être sélectionné.
  String _motifNonSelectionnable(Chauffeur c) {
    if (c.statut == ChauffeurStatus.suspendu) {
      final d = c.dateSuspension;
      return d != null
          ? 'Suspendu depuis le ${_formatDate(d)} — non affectable'
          : 'Suspendu — non affectable';
    }
    if (c.statut == ChauffeurStatus.enConge) {
      return 'En congé — non affectable';
    }
    if (c.vehiculeId != null) {
      final immat = c.vehiculeMatricule;
      return (immat != null && immat.isNotEmpty)
          ? 'Actif sur le véhicule $immat — déjà affecté'
          : 'Déjà affecté à un véhicule';
    }
    return '${c.statut?.label ?? 'Statut'} — non affectable';
  }

  void _avertirNonSelectionnable(Chauffeur c) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFC62828),
        content: Text(_motifNonSelectionnable(c)),
      ));
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Petite pastille de statut, pour distinguer les chauffeurs non affectables
/// (inactif/suspendu) lorsqu'on affiche l'ensemble du parc chauffeurs.
class _StatutPill extends StatelessWidget {
  final ChauffeurStatus? statut;
  const _StatutPill({required this.statut});

  static Color _color(ChauffeurStatus? s) => switch (s) {
        ChauffeurStatus.actif => const Color(0xFF2E7D32),
        ChauffeurStatus.inactif => Colors.grey,
        ChauffeurStatus.enConge => const Color(0xFFE65100),
        ChauffeurStatus.suspendu => const Color(0xFFC62828),
        null => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final color = _color(statut);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        statut?.label ?? 'Inconnu',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
