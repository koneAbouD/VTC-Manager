import 'package:flutter/material.dart';

import '../../features/chauffeur/presentation/pages/chauffeur_form_page.dart';
import '../../features/vehicule/presentation/pages/vehicule_form_page.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_header.dart';

class FleetActionSelectorPage extends StatelessWidget {
  const FleetActionSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(title: 'Ajouter à la flotte'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _ActionCard(
              icone: Icons.directions_car_outlined,
              titre: 'Ajouter un véhicule',
              description: 'Enregistrez un nouveau véhicule dans votre flotte',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VehiculeFormPage()),
              ),
            ),
            _ActionCard(
              icone: Icons.person_add_outlined,
              titre: 'Ajouter un chauffeur',
              description: 'Enregistrez un nouveau chauffeur dans votre équipe',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChauffeurFormPage()),
              ),
            ),
            _ActionCard(
              icone: Icons.upload_outlined,
              titre: 'Importer depuis Yango',
              description:
                  'Importez vos données existantes depuis la plateforme Yango',
              onTap: () {},
            ),
            _ActionCard(
              icone: Icons.link_outlined,
              titre: 'Lier à Yango',
              description:
                  'Connectez votre compte Yango pour synchroniser votre flotte',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String description;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icone,
    required this.titre,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icone, size: 21, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titre,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.dark)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.label)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.hint),
            ],
          ),
        ),
      ),
    );
  }
}
