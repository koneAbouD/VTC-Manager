/// Ouverture de WhatsApp sur une conversation, message pré-rempli.
///
/// C'est une **redirection**, pas un envoi : l'application quitte la main,
/// WhatsApp s'ouvre sur le destinataire avec le texte déjà écrit, et c'est le
/// guichetier qui appuie sur envoyer. Rien ne revient dire si le message est
/// parti — l'application ne peut donc pas prétendre l'avoir envoyé.
///
/// Le lien `wa.me` ne transporte que du texte : aucune pièce jointe n'est
/// possible par ce chemin.
library;

import 'package:url_launcher/url_launcher.dart';

import 'phone_formatter.dart';

/// Le lien qui ouvre la conversation de [telephone], message pré-rempli.
///
/// Un numéro absent ou inexploitable donne le lien sans destinataire : WhatsApp
/// s'ouvre alors sur son sélecteur de contacts, et le guichetier désigne
/// lui-même le chauffeur — mieux vaut cela que de refuser le geste parce qu'une
/// fiche est incomplète.
///
/// Le message est encodé composant par composant, et non via les
/// `queryParameters` de [Uri] : ceux-ci rendent les espaces en « + », que les
/// clients WhatsApp ne redécodent pas tous — un reçu criblé de « + » est
/// illisible.
Uri lienWhatsApp({String? telephone, required String message}) {
  final numero = PhoneFormatter.international(telephone);
  return Uri.parse('https://wa.me/${numero ?? ''}'
      '?text=${Uri.encodeComponent(message)}');
}

/// Ouvre WhatsApp sur la conversation de [telephone] avec [message] pré-rempli.
///
/// Retourne false si aucune application ne sait ouvrir le lien (WhatsApp
/// absent et aucun navigateur) ; lève si la plateforme refuse le lancement.
Future<bool> ouvrirWhatsApp({String? telephone, required String message}) =>
    launchUrl(lienWhatsApp(telephone: telephone, message: message),
        mode: LaunchMode.externalApplication);
