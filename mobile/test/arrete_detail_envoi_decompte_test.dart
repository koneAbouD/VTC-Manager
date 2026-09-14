import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:vtc_manager/features/tresorerie/domain/entities/compte_courant.dart';
import 'package:vtc_manager/features/tresorerie/presentation/pages/arrete_detail_page.dart';
import 'package:vtc_manager/features/tresorerie/presentation/providers/tresorerie_providers.dart';

/// L'envoi du décompte depuis le détail d'un arrêté : le bouton ne paraît que
/// sur un arrêté valide, et sa feuille nomme chaque chauffeur concerné — y
/// compris Koffi, dont Aya a soldé la dette et qui n'a donc pas de règlement.
ArreteCompte _arrete({String statut = 'VALIDE'}) => ArreteCompte(
      id: 12,
      perimetre: 'VEHICULE',
      perimetreId: 4,
      perimetreLibelle: '1234 AB 01',
      periodeDebut: DateTime(2026, 8, 1),
      periodeFin: DateTime(2026, 8, 31),
      dateArrete: DateTime(2026, 9, 1),
      reference: 'ARR-2026-000012',
      statut: statut,
      totalRestitue: 50000,
      lignes: const [
        LigneArrete(
            document: 'COTISATION',
            documentId: 1,
            chauffeurId: 3,
            vehiculeId: 4,
            montant: 100000,
            sens: 'CREDIT'),
        LigneArrete(
            document: 'RECETTE',
            documentId: 8,
            chauffeurId: 9,
            vehiculeId: 4,
            montant: 50000,
            sens: 'DEBIT'),
      ],
      reglements: const [
        ReglementArrete(
          chauffeurId: 3,
          chauffeurNom: 'Aya Traoré',
          totalCotisations: 100000,
          totalCreancesCompensees: 50000,
          montantNet: 50000,
          reliquatReporte: 0,
          modePaiement: 'ESPECES',
        ),
      ],
    );

Future<void> _ouvrir(WidgetTester tester, ArreteCompte arrete) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      arreteDetailProvider(12).overrideWith((ref) async => arrete),
      chauffeursArreteProvider(12).overrideWith((ref) async => const [
            ChauffeurArrete(id: 3, nom: 'Aya Traoré', telephone: '0712345678'),
            ChauffeurArrete(id: 9, nom: 'Koffi Yao'),
          ]),
    ],
    child: const MaterialApp(home: ArreteDetailPage(id: 12)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR', null));

  testWidgets('la feuille nomme chaque chauffeur concerné, celui sans règlement '
      'compris', (tester) async {
    await _ouvrir(tester, _arrete());

    final bouton = find.text('Envoyer le décompte aux chauffeurs');
    expect(bouton, findsOneWidget);

    await tester.ensureVisible(bouton);
    await tester.tap(bouton);
    await tester.pumpAndSettle();

    final feuille = find.byType(BottomSheet);
    Finder dansLaFeuille(Finder f) => find.descendant(of: feuille, matching: f);
    expect(dansLaFeuille(find.text('Envoyer le décompte')), findsOneWidget);
    expect(dansLaFeuille(find.text('Aya Traoré')), findsOneWidget);
    expect(dansLaFeuille(find.text('Koffi Yao')), findsOneWidget);
    // Koffi n'a pas de numéro : la feuille prévient que le contact sera à
    // désigner dans WhatsApp, sans refuser l'envoi.
    expect(dansLaFeuille(find.textContaining('numéro absent de sa fiche')),
        findsOneWidget);
  });

  testWidgets('un arrêté annulé ne propose pas d\'envoyer son décompte',
      (tester) async {
    await _ouvrir(tester, _arrete(statut: 'ANNULE'));

    expect(find.textContaining('Envoyer le décompte'), findsNothing);
  });
}
