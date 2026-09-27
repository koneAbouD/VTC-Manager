import 'package:intl/intl.dart';

import '../../../../core/utils/recu_paiement.dart';
import '../../../operation_financiere/domain/enums/mode_paiement.dart';
import '../../domain/entities/recu_ecritures.dart';

final _jourFmt = DateFormat('dd/MM/yyyy');

/// Lecture de `GET /recus/{ids}`.
///
/// Chaque créance est nommée comme sur la pièce de caisse — « Recette du
/// 11/09/2026 » —, à la journée réglée et non au jour du versement.
RecuEcritures recuEcrituresFromJson(Map<String, dynamic> json) {
  final lignes = (json['lignes'] as List? ?? const [])
      .cast<Map<String, dynamic>>();
  final vehicules = (json['vehicules'] as List? ?? const []).cast<String>();
  final modes = (json['modesPaiement'] as List? ?? const []).cast<String>();

  final paiements = [
    for (final l in lignes)
      if (l['payeLe'] != null) DateTime.parse(l['payeLe'] as String),
  ]..sort();

  return RecuEcritures(
    telephone: json['chauffeurTelephone'] as String?,
    recu: RecuPaiement(
      chauffeur: json['chauffeurNom'] as String?,
      // Un véhicule n'est nommé que s'il est le même partout.
      vehicule: vehicules.length == 1 ? vehicules.first : null,
      lignes: [
        for (final l in lignes)
          LigneRecu(
            libelle: l['journee'] == null
                ? (l['libelle'] as String? ?? 'Versement')
                : '${l['libelle'] ?? 'Versement'} du '
                    '${_jourFmt.format(DateTime.parse(l['journee'] as String))}',
            montant: (l['montant'] as num? ?? 0).toDouble(),
          ),
      ],
      // Plusieurs modes mêlés : le reçu se tait plutôt que d'en choisir un.
      modePaiement: modes.length == 1 ? _libelleMode(modes.first) : null,
      date: paiements.isEmpty ? DateTime.now() : paiements.last,
      reference: lignes.length == 1
          ? (lignes.first['referencePaiement'] ??
              lignes.first['referenceEcriture']) as String?
          : null,
      resteDu: (json['resteDu'] as num?)?.toDouble(),
    ),
  );
}

String? _libelleMode(String code) {
  try {
    return ModePaiementExt.fromString(code).libelle;
  } catch (_) {
    return null;
  }
}
