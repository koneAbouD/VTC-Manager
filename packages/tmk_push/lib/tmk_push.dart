/// Notifications push (Firebase Cloud Messaging) partagées par les applications
/// TMK.
///
/// Le package tient le jeton d'appareil à jour côté backend, transforme les
/// messages reçus en objets exploitables et diffère l'ouverture des liens
/// profonds tant que l'application est sous verrou — car toucher une
/// notification ramène presque toujours sur l'écran du code d'accès.
///
/// Chaque application fournit son [PushRegistrar] : les routes d'enregistrement
/// diffèrent (`/api/devices` pour le gestionnaire, `/api/me/devices` pour le
/// chauffeur), le reste est commun.
library tmk_push;

export 'src/banniere_push.dart';
export 'src/deep_link_queue.dart';
export 'src/push_message.dart';
export 'src/push_registrar.dart';
export 'src/push_service.dart' show PushService, gestionnaireArrierePlan;
