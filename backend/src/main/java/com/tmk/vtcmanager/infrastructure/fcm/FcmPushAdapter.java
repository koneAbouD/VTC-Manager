package com.tmk.vtcmanager.infrastructure.fcm;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.SendResponse;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.ResultatEnvoi;
import com.tmk.vtcmanager.application.ports.notification.PushNotificationPort;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;

/**
 * Envoi des notifications via Firebase Cloud Messaging.
 *
 * <p>En développement ({@code app.push.enabled=false}), rien n'est envoyé : le
 * message est journalisé, exactement comme le fait l'adaptateur WhatsApp pour
 * les OTP. Le reste de la chaîne — création de la notification, historique,
 * événements — fonctionne à l'identique, ce qui permet de tout tester sans
 * projet Firebase.
 */
@Slf4j
@Component
public class FcmPushAdapter implements PushNotificationPort {

    /**
     * Identifiant du canal de notification Android. Il doit être créé à
     * l'identique côté application : un canal inconnu prive la notification de
     * son son et de sa priorité, sans erreur visible côté serveur.
     */
    public static final String CANAL_ANDROID = "vtc_notifications_default";

    /** FCM plafonne un envoi groupé à 500 jetons. */
    private static final int TAILLE_LOT = 500;

    /**
     * Rejets définitifs : l'appareil ne reviendra pas. Les autres erreurs
     * (indisponibilité, quota) sont temporaires et ne doivent surtout pas
     * entraîner la désactivation du jeton.
     */
    private static final Set<MessagingErrorCode> REJETS_DEFINITIFS =
            EnumSet.of(MessagingErrorCode.UNREGISTERED, MessagingErrorCode.INVALID_ARGUMENT);

    private final ObjectProvider<FirebaseMessaging> messagingProvider;
    private final boolean enabled;
    private final boolean dryRun;

    public FcmPushAdapter(
            ObjectProvider<FirebaseMessaging> messagingProvider,
            @Value("${app.push.enabled:false}") boolean enabled,
            @Value("${app.push.dry-run:false}") boolean dryRun) {
        this.messagingProvider = messagingProvider;
        this.enabled = enabled;
        this.dryRun = dryRun;
    }

    @Override
    public ResultatEnvoi envoyer(List<String> tokens, Notification notification) {
        if (tokens == null || tokens.isEmpty()) {
            return ResultatEnvoi.aucunDestinataire();
        }

        if (!enabled) {
            log.info("[Push DÉSACTIVÉ] « {} — {} » vers {} appareil(s) (activez app.push.enabled)",
                    notification.getTitre(), notification.getCorps(), tokens.size());
            return ResultatEnvoi.aucunDestinataire();
        }

        FirebaseMessaging messaging = messagingProvider.getIfAvailable();
        if (messaging == null) {
            log.error("app.push.enabled=true mais Firebase n'est pas initialisé : envoi abandonné");
            return ResultatEnvoi.aucunDestinataire();
        }

        int succes = 0;
        int echecs = 0;
        List<String> tokensInvalides = new ArrayList<>();

        for (int debut = 0; debut < tokens.size(); debut += TAILLE_LOT) {
            List<String> lot = tokens.subList(debut, Math.min(debut + TAILLE_LOT, tokens.size()));
            try {
                BatchResponse reponse = messaging.sendEachForMulticast(construireMessage(lot, notification), dryRun);
                succes += reponse.getSuccessCount();
                echecs += reponse.getFailureCount();
                collecterTokensInvalides(lot, reponse, tokensInvalides);
            } catch (FirebaseMessagingException e) {
                // Panne du lot entier (réseau, authentification) : aucun jeton
                // n'est en cause, donc aucun n'est désactivé.
                echecs += lot.size();
                log.error("Échec de l'envoi push vers {} appareil(s) : {}", lot.size(), e.getMessage());
            }
        }

        if (!tokensInvalides.isEmpty()) {
            log.info("{} jeton(s) d'appareil rejeté(s) par FCM, à désactiver", tokensInvalides.size());
        }
        return new ResultatEnvoi(succes, echecs, tokensInvalides);
    }

    private void collecterTokensInvalides(List<String> lot, BatchResponse reponse, List<String> cible) {
        List<SendResponse> reponses = reponse.getResponses();
        for (int i = 0; i < reponses.size(); i++) {
            SendResponse envoi = reponses.get(i);
            if (envoi.isSuccessful() || envoi.getException() == null) {
                continue;
            }
            MessagingErrorCode code = envoi.getException().getMessagingErrorCode();
            if (code != null && REJETS_DEFINITIFS.contains(code)) {
                cible.add(lot.get(i));
            } else {
                log.warn("Échec temporaire d'envoi push ({}) : {}", code, envoi.getException().getMessage());
            }
        }
    }

    private MulticastMessage construireMessage(List<String> tokens, Notification notification) {
        return MulticastMessage.builder()
                .addAllTokens(tokens)
                .setNotification(com.google.firebase.messaging.Notification.builder()
                        .setTitle(notification.getTitre())
                        .setBody(notification.getCorps())
                        .build())
                // Charge utile technique : de quoi ouvrir le bon écran, rien de plus.
                .putAllData(notification.donneesPush())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .setNotification(AndroidNotification.builder()
                                .setChannelId(CANAL_ANDROID)
                                .build())
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder().setSound("default").build())
                        .build())
                .build();
    }
}
