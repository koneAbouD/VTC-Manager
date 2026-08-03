/// Une notification telle qu'elle arrive sur l'appareil.
///
/// Le backend n'envoie dans la charge utile que des identifiants — type,
/// numéro de la notification, objet visé. Les montants, les noms et les
/// immatriculations n'y figurent pas : une notification s'affiche sur l'écran
/// verrouillé, en dehors du code d'accès qui protège l'application. Le détail
/// se charge à l'ouverture, une fois l'utilisateur identifié.
class PushMessage {
  /// Nature de l'événement, miroir de `TypeNotification` côté backend
  /// (`PENALITE_APPLIQUEE`, `MAINTENANCE_A_VENIR`, `TEST`…).
  final String type;

  /// Identifiant de la notification dans le centre de notifications.
  final int? notificationId;

  /// Objet visé par le lien profond (ex. `LIGNE_PENALITE`).
  final String? entiteType;

  /// Identifiant de cet objet.
  final int? entiteId;

  /// Texte affiché, présent seulement quand le message porte une notification
  /// visible — un message de données seules n'en a pas.
  final String? titre;
  final String? corps;

  const PushMessage({
    required this.type,
    this.notificationId,
    this.entiteType,
    this.entiteId,
    this.titre,
    this.corps,
  });

  /// Construit le message à partir de la charge utile FCM.
  ///
  /// Rend `null` si la charge n'est pas exploitable. FCM transporte des
  /// messages qui ne viennent pas forcément de nous — sondes de la console
  /// Firebase, campagnes — et une notification sans `type` ne saurait de toute
  /// façon ouvrir aucun écran.
  static PushMessage? depuisCharge(
    Map<String, dynamic> donnees, {
    String? titre,
    String? corps,
  }) {
    final type = donnees['type'];
    if (type is! String || type.isEmpty) return null;

    return PushMessage(
      type: type,
      notificationId: _entier(donnees['notificationId']),
      entiteType: _texte(donnees['entiteType']),
      entiteId: _entier(donnees['entiteId']),
      titre: titre,
      corps: corps,
    );
  }

  /// Vrai lorsque le message désigne un écran à ouvrir.
  bool get ouvreUnEcran => entiteType != null && entiteId != null;

  /// FCM ne transporte que des chaînes dans la charge utile, quel que soit le
  /// type d'origine côté serveur.
  static int? _entier(Object? valeur) => switch (valeur) {
        final int i => i,
        final String s => int.tryParse(s),
        _ => null,
      };

  static String? _texte(Object? valeur) {
    if (valeur is! String || valeur.isEmpty) return null;
    return valeur;
  }

  @override
  String toString() => 'PushMessage($type, entite=$entiteType/$entiteId)';
}
