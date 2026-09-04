import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../vehicule/domain/entities/statut_vehicule.dart';
import '../../../vehicule/presentation/providers/referentiel_provider.dart';
import '../../data/models/etat_parc_summary_model.dart';
import '../providers/etat_parc_provider.dart';

/// Icône de présentation d'un motif d'exception. Partagée par la liste
/// « véhicules demandant une action » et par ce sélecteur, pour que la même
/// ligne porte partout le même pictogramme.
IconData iconeMotifException(String? motif) => switch (motif) {
      'IMMOBILISATION_PENALITE' => Icons.gavel_rounded,
      'IMMOBILISATION_INDISPONIBILITE' => Icons.no_transfer_rounded,
      'PANNE_OU_ACCIDENT' => Icons.car_crash_rounded,
      'MAINTENANCE_EN_COURS' => Icons.build_rounded,
      'MAINTENANCE_PREVUE' => Icons.event_available_rounded,
      'VIDANGE_DUE' => Icons.oil_barrel_rounded,
      'SANS_CHAUFFEUR' => Icons.person_off_rounded,
      'SORTIE_PARC' => Icons.logout_rounded,
      'DECISION_MANUELLE' => Icons.pan_tool_rounded,
      _ => Icons.directions_car_rounded,
    };

/// Une entrée proposée par le sélecteur : un critère, son libellé et le nombre
/// de véhicules qu'il retient.
class CritereException {
  final ExceptionCritere critere;
  final String libelle;
  final IconData icone;
  final Color couleur;
  final int nombre;

  const CritereException({
    required this.critere,
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.nombre,
  });
}

/// Motifs proposés pour une liste d'exceptions donnée : uniquement ceux qui
/// retiennent au moins un véhicule, les plus nombreux d'abord.
///
/// La liste est vide s'il n'y a qu'un seul motif présent : filtrer dessus
/// reviendrait à « Tous ».
List<CritereException> criteresDisponibles(
  List<VehiculeExceptionModel> exceptions,
  List<StatutVehicule> statutsRef,
) {
  final parMotif = <String, int>{};
  final libelleMotif = <String, String>{};

  for (final e in exceptions) {
    if (e.motif == null) continue;
    parMotif.update(e.motif!, (n) => n + 1, ifAbsent: () => 1);
    libelleMotif[e.motif!] = e.motifLabel;
  }

  final motifs = parMotif.entries.map((entry) {
    // Couleur du statut porté par les véhicules de ce motif (un motif ne
    // couvre qu'un statut en pratique ; le premier trouvé suffit).
    final statutDuMotif =
        exceptions.firstWhere((e) => e.motif == entry.key).statut;
    return CritereException(
      critere: ExceptionCritere(motif: entry.key),
      libelle: libelleMotif[entry.key] ?? entry.key,
      icone: iconeMotifException(entry.key),
      couleur: StatutVehicule.resolve(statutDuMotif, statutsRef).couleur,
      nombre: entry.value,
    );
  }).toList()
    ..sort((a, b) {
      final parNombre = b.nombre.compareTo(a.nombre);
      return parNombre != 0 ? parNombre : a.libelle.compareTo(b.libelle);
    });

  return motifs.length >= 2 ? motifs : const <CritereException>[];
}

/// Libellé du critère courant, tel qu'affiché sur le bouton de filtre.
String libelleCritereException(
  ExceptionCritere critere,
  List<VehiculeExceptionModel> exceptions,
) {
  if (critere.motif == null) return 'Tous';
  final e = exceptions.where((x) => x.motif == critere.motif).firstOrNull;
  return e?.motifLabel ?? critere.motif!;
}

/// Ouvre le sélecteur de critère de la liste « véhicules demandant une action ».
Future<void> showEtatParcExceptionFiltreSheet(
  BuildContext context,
  List<VehiculeExceptionModel> exceptions,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ExceptionFiltreSheet(exceptions: exceptions),
  );
}

class _ExceptionFiltreSheet extends ConsumerWidget {
  final List<VehiculeExceptionModel> exceptions;
  const _ExceptionFiltreSheet({required this.exceptions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statutsRef = ref.watch(statutsVehiculeResolvedProvider);
    final courant = ref.watch(etatParcExceptionCritereProvider);
    final criteres = criteresDisponibles(exceptions, statutsRef);

    void choisir(ExceptionCritere critere) {
      ref.read(etatParcExceptionCritereProvider.notifier).state = critere;
      Navigator.of(context).pop();
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Filtrer les véhicules',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 12),
                children: [
                  _CritereTile(
                    libelle: 'Tous',
                    icone: Icons.all_inclusive_rounded,
                    couleur: Colors.grey.shade600,
                    nombre: exceptions.length,
                    selectionne: !courant.estActif,
                    onTap: () => choisir(const ExceptionCritere()),
                  ),
                  for (final c in criteres)
                    _CritereTile(
                      libelle: c.libelle,
                      icone: c.icone,
                      couleur: c.couleur,
                      nombre: c.nombre,
                      selectionne: courant == c.critere,
                      onTap: () => choisir(c.critere),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CritereTile extends StatelessWidget {
  final String libelle;
  final IconData icone;
  final Color couleur;
  final int nombre;
  final bool selectionne;
  final VoidCallback onTap;

  const _CritereTile({
    required this.libelle,
    required this.icone,
    required this.couleur,
    required this.nombre,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const vert = Color(0xFF43A047);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: couleur.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 18, color: couleur),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                libelle,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectionne ? FontWeight.w700 : FontWeight.w500,
                  color: selectionne ? vert : const Color(0xFF1A1A2E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$nombre',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            SizedBox(
              width: 28,
              child: selectionne
                  ? const Icon(Icons.check_rounded, size: 19, color: vert)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
