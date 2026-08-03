import 'package:tmk_push/tmk_push.dart';

import '../../../core/storage/secure_storage.dart';

/// Réception des notifications sur cet appareil — ce que commande
/// l'interrupteur des réglages.
///
/// Couper ne masque rien côté application : le jeton de l'appareil est retiré
/// du compte, et le backend n'a alors plus où pousser. C'est la seule façon
/// honnête de tenir la promesse — une notification affichée par le système ne
/// se rattrape pas après coup.
///
/// Le réglage vaut pour cet appareil, pas pour le compte : couper sur son
/// téléphone ne fait pas taire celui d'un collègue connecté ailleurs.
class ReceptionPush {
  final SecureStorage _storage;
  final PushRegistrar _registrar;

  const ReceptionPush(this._storage, this._registrar);

  Future<bool> estActive() async => !await _storage.notificationsCoupees();

  /// Rend `null` si l'opération a abouti, sinon le message à montrer.
  ///
  /// L'échec le plus courant n'est pas technique : Android 13 et plus exigent
  /// une autorisation système, et un refus définitif ne rouvre plus aucune
  /// boîte de dialogue. L'interrupteur ne peut alors rien faire, et le dire est
  /// plus utile que de basculer dans le vide.
  Future<String?> activer() async {
    if (!await PushService.instance.demanderPermission()) {
      return 'Autorisez les notifications pour l\'application dans les '
          'réglages de votre téléphone.';
    }
    await _storage.setNotificationsCoupees(false);
    await PushService.instance.attacherSession(_registrar);
    return null;
  }

  /// Rend `null` si l'appareil a bien été retiré, sinon l'avertissement à
  /// montrer — la coupure est prise localement dans tous les cas.
  Future<String?> couper() async {
    // La préférence est posée avant l'appel réseau : c'est elle qui empêche le
    // réenregistrement à la prochaine ouverture, et qui déclenchera une
    // nouvelle tentative de retrait si celle-ci échoue.
    await _storage.setNotificationsCoupees(true);

    if (await PushService.instance.couperReception(_registrar)) return null;
    return 'Notifications coupées sur cet appareil. Le serveur n\'a pas '
        'confirmé : quelques alertes peuvent encore arriver d\'ici la '
        'prochaine ouverture.';
  }
}
