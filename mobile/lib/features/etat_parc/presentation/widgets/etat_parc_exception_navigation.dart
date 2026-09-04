import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exception.dart';
import '../../../indisponibilite/presentation/pages/indisponibilite_vehicule_detail_page.dart';
import '../../../indisponibilite/presentation/providers/indisponibilite_vehicule_provider.dart';
import '../../../maintenance/presentation/pages/maintenance_detail_page.dart';
import '../../../maintenance/presentation/providers/maintenance_provider.dart';
import '../../../vehicule/presentation/pages/vehicule_detail_page.dart';
import '../../../vehicule/presentation/pages/vidanges_historique_page.dart';
import '../../data/models/etat_parc_summary_model.dart';

/// Index de l'onglet « Pénalités » dans [VehiculeDetailPage] (Infos, Documents,
/// Programme, Recettes, Cotisations, Pénalités).
const int _ongletPenalitesVehicule = 5;

/// Ouvre une ligne de « Véhicules demandant une action » sur l'objet qui
/// explique l'arrêt : l'intervention, l'immobilisation datée, les pénalités du
/// véhicule ou son historique de vidanges — à défaut sa fiche.
///
/// Le serveur ne transmet que le type de cible et son identifiant : les écrans
/// de détail attendant l'entité complète, elle est chargée ici, d'où le
/// [Future] — l'appelant s'en sert pour afficher son indicateur d'attente.
/// Une cible illisible (supprimée entre-temps, réseau coupé) laisse l'écran en
/// place et signale l'échec plutôt que d'ouvrir une page vide.
Future<void> ouvrirCibleException(
  BuildContext context,
  WidgetRef ref,
  VehiculeExceptionModel exception,
) async {
  final vehiculeId = exception.vehiculeId;
  if (vehiculeId == null) return;

  void pousser(Widget page) {
    if (!context.mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void echouer(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  final cibleId = exception.cibleId;

  switch (exception.cible) {
    case 'MAINTENANCE' when cibleId != null:
      final resultat =
          await ref.read(maintenanceRepositoryProvider).getMaintenanceById(cibleId);
      resultat.fold(
        (failure) => echouer(failure.message),
        (maintenance) => pousser(MaintenanceDetailPage(maintenance: maintenance)),
      );

    case 'INDISPONIBILITE_VEHICULE' when cibleId != null:
      try {
        final indisponibilite = await ref
            .read(indisponibiliteVehiculeDatasourceProvider)
            .getById(cibleId);
        pousser(IndisponibiliteVehiculeDetailPage(
            indisponibilite: indisponibilite));
      } catch (e) {
        echouer(messageFromError(e));
      }

    case 'VIDANGE':
      pousser(VidangesHistoriquePage(
        vehiculeId: vehiculeId,
        vehiculeLabel: exception.immatriculation,
      ));

    case 'PENALITE':
      pousser(VehiculeDetailPage(
        vehiculeId: vehiculeId,
        initialTabIndex: _ongletPenalitesVehicule,
      ));

    // Aucun objet ne porte l'arrêt (sans chauffeur, panne saisie à la main,
    // décision manuelle) : la fiche véhicule est le bon point d'entrée.
    default:
      pousser(VehiculeDetailPage(vehiculeId: vehiculeId));
  }
}
