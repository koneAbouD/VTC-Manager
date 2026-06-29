import 'package:flutter/material.dart';

import '../../features/chauffeur/presentation/pages/chauffeur_form_page.dart';
import '../../features/vehicule/presentation/pages/vehicule_form_page.dart';
import '../../core/widgets/app_header.dart';

class FleetActionSelectorPage extends StatelessWidget {
  const FleetActionSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(title: 'Ajouter à la flotte'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          children: [
              _ActionCard(
                icon: Icons.directions_car_outlined,
                iconColor: Colors.blue.shade700,
                iconBg: Colors.blue.shade50,
                title: 'Ajouter un véhicule',
                subtitle: 'Enregistrez un nouveau véhicule dans votre flotte',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VehiculeFormPage()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.person_add_outlined,
                iconColor: Colors.green.shade700,
                iconBg: Colors.green.shade50,
                title: 'Ajouter un chauffeur',
                subtitle: 'Enregistrez un nouveau chauffeur dans votre équipe',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChauffeurFormPage()),
                ),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.upload_outlined,
                iconColor: Colors.orange.shade700,
                iconBg: Colors.orange.shade50,
                title: 'Importer depuis Yango',
                subtitle: 'Importez vos données existantes depuis la plateforme Yango',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.link_outlined,
                iconColor: Colors.purple.shade700,
                iconBg: Colors.purple.shade50,
                title: 'Lier à Yango',
                subtitle: 'Connectez votre compte Yango pour synchroniser votre flotte',
                onTap: () {},
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }
}
