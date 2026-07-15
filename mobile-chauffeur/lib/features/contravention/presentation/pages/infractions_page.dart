import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_header.dart';
import '../../../penalite/presentation/pages/penalites_page.dart';
import 'contraventions_page.dart';

enum _Vue { contraventions, amendes }

/// Onglet regroupant contraventions (infractions routières) et amendes
/// (pénalités), avec un sélecteur pour basculer de l'une à l'autre.
class InfractionsPage extends StatefulWidget {
  const InfractionsPage({super.key});

  @override
  State<InfractionsPage> createState() => _InfractionsPageState();
}

class _InfractionsPageState extends State<InfractionsPage> {
  _Vue _vue = _Vue.contraventions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(titre: 'Contraventions & Amendes'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<_Vue>(
                segments: const [
                  ButtonSegment(
                    value: _Vue.contraventions,
                    icon: Icon(Icons.gavel_rounded),
                    label: Text('Contraventions'),
                  ),
                  ButtonSegment(
                    value: _Vue.amendes,
                    icon: Icon(Icons.receipt_long_rounded),
                    label: Text('Amendes'),
                  ),
                ],
                selected: {_vue},
                onSelectionChanged: (s) => setState(() => _vue = s.first),
              ),
            ),
            Expanded(
              child: _vue == _Vue.contraventions
                  ? const ContraventionsPage()
                  : const PenalitesPage(),
            ),
          ],
        ),
      ),
    );
  }
}
