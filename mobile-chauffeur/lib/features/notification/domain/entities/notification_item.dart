/// Une notification adressée au chauffeur.
class NotificationItem {
  final int id;

  /// Type métier (`PENALITE_APPLIQUEE`, `ARRETE_COMPTE_DISPONIBLE`…). Il
  /// détermine l'icône et l'écran ouvert au toucher.
  final String type;

  final String titre;
  final String corps;

  /// Ce que le corps tait : chauffeur, véhicule, montants. Absent du message
  /// poussé — il ne s'affiche donc jamais sur l'écran verrouillé.
  final String? detail;

  /// Cible du lien, quand la notification en désigne une.
  final String? entiteType;
  final int? entiteId;

  final bool lue;
  final DateTime? creeLe;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.titre,
    required this.corps,
    required this.lue,
    this.detail,
    this.entiteType,
    this.entiteId,
    this.creeLe,
  });
}

/// Contenu du centre de notifications : la liste et le nombre de non-lues,
/// rendus ensemble parce que l'écran a besoin des deux en même temps.
class CentreNotifications {
  final List<NotificationItem> notifications;
  final int nonLues;

  const CentreNotifications({
    required this.notifications,
    required this.nonLues,
  });

  static const vide = CentreNotifications(notifications: [], nonLues: 0);
}
