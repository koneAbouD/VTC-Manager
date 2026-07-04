import 'package:flutter/material.dart';

import '../../../../core/widgets/app_header.dart';
import '../widgets/etat_parc_tab.dart';

/// Page autonome « État de parc » : synthèse des effectifs par statut,
/// taux de disponibilité / d'utilisation, immobilisés, répartition du parc,
/// véhicules demandant une action et alertes préventives.
///
/// Le contenu (responsive téléphone / tablette) est fourni par [EtatParcTab].
class EtatParcPage extends StatelessWidget {
  const EtatParcPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppHeader(title: 'État de parc'),
      body: EtatParcTab(),
    );
  }
}
