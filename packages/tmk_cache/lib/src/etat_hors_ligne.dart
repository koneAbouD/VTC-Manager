import 'package:flutter/foundation.dart';

/// Les écrans affichent-ils des données du cache faute de réseau ?
///
/// La valeur est l'heure de la plus ancienne réponse servie depuis le cache
/// depuis la dernière réponse du serveur, `null` quand tout vient du serveur.
/// Les clients HTTP la tiennent à jour ; le [BandeauHorsLigne] l'affiche.
class EtatHorsLigne extends ValueNotifier<DateTime?> {
  EtatHorsLigne() : super(null);

  static final instance = EtatHorsLigne();

  /// Un écran vient de recevoir une réponse du cache enregistrée à [le].
  void donneesDuCache(DateTime le) {
    final actuel = value;
    if (actuel == null || le.isBefore(actuel)) value = le;
  }

  /// Le serveur a répondu : le réseau est revenu.
  void serveurJoignable() => value = null;
}
