import 'diagnostic_reseau.dart';

/// Sur le web, ni erreur système lisible ni connexion TCP : rien à trancher.
CauseIndisponibilite? causeCertaine(Object erreur) => null;

Future<bool?> sonderInternet() async => null;
