package com.tmk.vtcmanager.application.ports.notification;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.ResultatEnvoi;

import java.util.List;

/**
 * Port d'envoi d'une notification vers les appareils d'un destinataire.
 *
 * <p>L'implémentation ne lève pas d'exception sur un échec de livraison : un
 * appareil injoignable est un fait ordinaire, pas une erreur de traitement. Le
 * bilan est rendu dans {@link ResultatEnvoi}, dont les jetons rejetés sont à
 * désactiver par l'appelant.
 */
public interface PushNotificationPort {

    ResultatEnvoi envoyer(List<String> tokens, Notification notification);
}
