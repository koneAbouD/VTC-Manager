import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/chauffeur/domain/enums/chauffeur_status.dart';

/// Index du sous-onglet actif dans FleetScreen (0=État de parc, 1=Véhicules, 2=Chauffeurs).
final fleetActiveTabProvider = StateProvider<int>((ref) => 0);

/// Filtre texte appliqué sur l'onglet Véhicules.
final vehiculeFilterQueryProvider = StateProvider<String>((ref) => '');

/// Filtre statut appliqué sur l'onglet Véhicules.
final vehiculeFilterStatutProvider = StateProvider<String?>((ref) => null);

/// Filtre texte appliqué sur l'onglet Chauffeurs.
final chauffeurFilterQueryProvider = StateProvider<String>((ref) => '');

/// Filtre statut appliqué sur l'onglet Chauffeurs.
final chauffeurFilterStatutProvider =
    StateProvider<ChauffeurStatus?>((ref) => null);
