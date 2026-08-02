import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/parametrage_api.dart';

/// Accès REST au module de paramétrage.
final parametrageApiProvider = Provider<ParametrageApi>(
  (ref) => ParametrageApi(ref.watch(apiClientProvider)),
);

/// Meta-catalogue : liste des référentiels paramétrables et leur schéma.
final catalogueProvider = FutureProvider<List<ReferentielDescriptor>>(
  (ref) => ref.watch(parametrageApiProvider).catalogue(),
);

/// Items d'un référentiel donné, indexés par son endpoint.
/// Invalidé après chaque mutation pour rafraîchir la liste.
final referentielItemsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, endpoint) => ref.watch(parametrageApiProvider).lister(endpoint),
);

/// Réglages globaux de l'application (paramètres clé-valeur).
/// Invalidé après chaque mise à jour pour rafraîchir l'écran.
final parametresProvider = FutureProvider<List<ParametreGeneral>>(
  (ref) => ref.watch(parametrageApiProvider).parametres(),
);

// La durée d'amortissement effective n'est plus dérivée ici : le backend la
// sert avec la VNC dans la fiche véhicule, sur le plan qui alimente le bilan.
// La recalculer côté client rouvrait un écart entre la fiche et l'actif.
