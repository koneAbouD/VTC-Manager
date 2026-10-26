import 'dart:io';

import 'diagnostic_reseau.dart';

/// Codes d'erreur système, selon la plateforme (iOS/macOS, Android/Linux,
/// Windows).
const _connexionRefusee = {61, 111, 10061};
const _reseauInjoignable = {51, 101, 10051};

/// Cause lisible dans l'erreur elle-même, ou `null` s'il faut sonder.
CauseIndisponibilite? causeCertaine(Object erreur) {
  if (erreur is! SocketException) return null;
  final code = erreur.osError?.errorCode;
  if (_connexionRefusee.contains(code)) return CauseIndisponibilite.serveur;
  if (_reseauInjoignable.contains(code)) return CauseIndisponibilite.reseau;
  return null;
}

/// Internet est-il joignable ? Ouverture d'une connexion TCP vers 1.1.1.1:443,
/// refermée aussitôt : rien n'est envoyé.
Future<bool?> sonderInternet() async {
  try {
    final socket = await Socket.connect('1.1.1.1', 443,
        timeout: const Duration(seconds: 3));
    socket.destroy();
    return true;
  } catch (_) {
    return false;
  }
}
