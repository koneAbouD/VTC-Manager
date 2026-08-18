import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tmk_pin/tmk_pin.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/profil_api.dart';

final profilApiProvider =
    Provider<ProfilApi>((ref) => ProfilApi(ref.watch(apiClientProvider)));

/// Fiche du compte connecté, servie par le référentiel d'identité.
///
/// Source de vérité de l'écran « Mes informations personnelles » : le jeton,
/// lui, ne porte que ce qu'il portait à sa délivrance — il reste en retard
/// d'une modification jusqu'au renouvellement suivant.
final monProfilProvider = FutureProvider<ProfilUtilisateur>(
  (ref) => ref.watch(profilApiProvider).lire(),
);

/// Identité du compte telle qu'elle s'affiche : nom présenté « Prénom NOM »,
/// identifiant de connexion, e-mail.
typedef IdentiteCompte = ({
  String nomComplet,
  String identifiant,
  String email,
});

/// Identité lue dans le jeton courant : disponible tout de suite et hors
/// ligne, là où [monProfilProvider] demande un aller-retour réseau.
final identiteCompteProvider = FutureProvider<IdentiteCompte>((ref) async {
  final token = await ref.watch(secureStorageProvider).getAccessToken();
  final claims = JwtClaims.parse(token);

  return composerIdentite(
    prenom: claims.givenName,
    nom: claims.string('family_name'),
    // À défaut du couple prénom/nom, le `name` complet que Keycloak compose.
    nomComplet: claims.string('name'),
    identifiant: claims.preferredUsername,
    email: claims.string('email'),
  );
});

/// Même présentation pour les deux sources — jeton ou fiche Keycloak — afin
/// que le bandeau des réglages ne change pas d'allure selon qui l'alimente.
IdentiteCompte composerIdentite({
  String? prenom,
  String? nom,
  String? nomComplet,
  String? identifiant,
  String? email,
}) {
  final prenomNom = [
    capitaliser(prenom ?? ''),
    (nom ?? '').toUpperCase(),
  ].where((part) => part.isNotEmpty).join(' ');

  final compte = (identifiant ?? '').trim();
  final adresse = (email ?? '').trim();

  return (
    nomComplet: prenomNom.isNotEmpty ? prenomNom : (nomComplet ?? '').trim(),
    identifiant: compte,
    // Beaucoup de comptes se connectent avec leur e-mail : on ne l'affiche
    // qu'une fois.
    email: adresse.toLowerCase() == compte.toLowerCase() ? '' : adresse,
  );
}

/// Première lettre en majuscule, le reste inchangé — sauf si la valeur est
/// entièrement capitalisée (« ABOU »), auquel cas elle repasse en casse
/// normale plutôt que de crier.
String capitaliser(String valeur) {
  final v = valeur.trim();
  if (v.isEmpty) return v;
  final base = v == v.toUpperCase() ? v.toLowerCase() : v;
  return base[0].toUpperCase() + base.substring(1);
}
