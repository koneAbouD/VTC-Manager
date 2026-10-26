import 'package:flutter/foundation.dart';

import 'diagnostic_reseau.dart';

/// Les écrans affichent-ils des données du cache faute de serveur ?
///
/// La valeur est l'heure de la plus ancienne réponse servie depuis le cache
/// depuis la dernière réponse du serveur, `null` quand tout vient du serveur.
/// [cause] dit pourquoi : pas d'internet, ou serveur indisponible. Les clients
/// HTTP la tiennent à jour ; le [BandeauHorsLigne] l'affiche.
class EtatHorsLigne extends ValueNotifier<DateTime?> {
  EtatHorsLigne() : super(null);

  static final instance = EtatHorsLigne();

  CauseIndisponibilite _cause = CauseIndisponibilite.inconnue;

  /// Cause de la dernière indisponibilité constatée.
  CauseIndisponibilite get cause => _cause;

  /// Un écran vient de recevoir une réponse du cache enregistrée à [le],
  /// faute de serveur pour la [cause] donnée.
  void donneesDuCache(
    DateTime le, {
    CauseIndisponibilite cause = CauseIndisponibilite.inconnue,
  }) {
    final actuel = value;
    final causeChangee = cause != _cause;
    _cause = cause;
    if (actuel == null || le.isBefore(actuel)) {
      value = le;
    } else if (causeChangee) {
      notifyListeners();
    }
  }

  /// Le serveur a répondu : le réseau est revenu.
  void serveurJoignable() => value = null;
}
