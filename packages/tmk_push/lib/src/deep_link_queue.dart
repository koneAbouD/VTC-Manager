import 'dart:async';

import 'push_message.dart';

/// Retient le lien profond d'une notification jusqu'à ce que l'application soit
/// en état de l'ouvrir.
///
/// Les applications TMK se remettent sous clé dès qu'elles passent en arrière-
/// plan un peu longtemps, et toucher une notification les ramène presque
/// toujours sur l'écran du code d'accès. Naviguer à ce moment-là serait au
/// mieux inutile — l'écran serait aussitôt recouvert — au pire une fuite : la
/// page visée s'afficherait derrière la saisie du code.
///
/// Le lien attend donc le déverrouillage, puis est rejoué. Un seul lien est
/// conservé : lorsqu'on en reçoit plusieurs, seul le dernier touché compte,
/// c'est celui que l'utilisateur veut voir.
class DeepLinkQueue {
  PushMessage? _enAttente;
  bool _pret = false;

  final StreamController<PushMessage> _controleur =
      StreamController<PushMessage>.broadcast();

  /// Liens à ouvrir. N'émet que lorsque l'application est déverrouillée.
  Stream<PushMessage> get flux => _controleur.stream;

  /// Vrai tant qu'un lien attend le déverrouillage.
  bool get aUnLienEnAttente => _enAttente != null;

  /// Dépose un lien : émis tout de suite si l'application est prête, retenu
  /// sinon.
  void deposer(PushMessage message) {
    if (_pret) {
      _controleur.add(message);
      return;
    }
    _enAttente = message;
  }

  /// L'application est déverrouillée : le lien retenu peut s'ouvrir.
  void marquerPrete() {
    _pret = true;
    final enAttente = _enAttente;
    if (enAttente != null) {
      _enAttente = null;
      _controleur.add(enAttente);
    }
  }

  /// L'application se remet sous clé : les liens suivants attendront de nouveau.
  void marquerVerrouillee() {
    _pret = false;
  }

  /// Déconnexion : le lien retenu appartenait à la session qui se ferme, il ne
  /// doit pas s'ouvrir pour le compte suivant.
  void vider() {
    _enAttente = null;
    _pret = false;
  }

  Future<void> fermer() => _controleur.close();
}
