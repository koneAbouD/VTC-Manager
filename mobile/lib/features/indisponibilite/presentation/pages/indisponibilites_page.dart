import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../providers/indisponibilite_provider.dart';
import '../providers/indisponibilite_vehicule_provider.dart';
import 'indisponibilite_form_page.dart';
import 'indisponibilite_vehicule_form_page.dart';
import 'indisponibilites_chauffeur_tab.dart';
import 'indisponibilites_vehicule_tab.dart';

/// Page Indisponibilités : deux onglets segmentés — indisponibilités
/// **Chauffeurs** (congé, maladie…) et immobilisations **Véhicules**
/// (accident, panne, administratif…). Le bouton « + » de l'en-tête crée
/// l'élément correspondant à l'onglet actif.
class IndisponibilitesPage extends ConsumerStatefulWidget {
  const IndisponibilitesPage({super.key});

  @override
  ConsumerState<IndisponibilitesPage> createState() => _State();
}

class _State extends ConsumerState<IndisponibilitesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_tab.index == 0) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IndisponibiliteFormPage()),
      );
      if (mounted) {
        ref.read(indisponibilitesListeProvider.notifier).refresh();
      }
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const IndisponibiliteVehiculeFormPage()),
      );
      if (mounted) {
        ref.read(indisponibilitesVehiculeListeProvider.notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeader(
        title: 'Indisponibilités',
        action: AppHeaderAction(icon: Icons.add_rounded, onTap: _add),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tab,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade600,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: 'Chauffeurs'),
                Tab(text: 'Véhicules'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                IndisponibilitesChauffeurTab(),
                IndisponibilitesVehiculeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
