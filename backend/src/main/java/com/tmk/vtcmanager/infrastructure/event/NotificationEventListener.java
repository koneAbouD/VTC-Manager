package com.tmk.vtcmanager.infrastructure.event;

import com.tmk.vtcmanager.application.domain.notification.event.NotificationCreeeEvent;
import com.tmk.vtcmanager.application.usecases.notification.PousserNotificationUseCase;
import com.tmk.vtcmanager.infrastructure.config.NotificationAsyncConfig;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Déclenche l'envoi push une fois la transaction émettrice validée.
 *
 * <p>Les deux annotations sont indissociables :
 *
 * <ul>
 *   <li>{@code AFTER_COMMIT} — rien n'est poussé pour une opération annulée.
 *       Un chauffeur ne doit pas être averti d'une pénalité que le rollback
 *       vient d'effacer, et une notification est irrattrapable une fois partie.
 *   <li>{@code @Async} — l'aller-retour vers FCM sort du fil de la requête.
 *       Une génération de pénalités porte des centaines de lignes : elle ne
 *       peut pas attendre autant d'appels réseau.
 * </ul>
 *
 * <p>{@code fallbackExecution} traite le cas où l'émetteur n'a pas de
 * transaction — un appel direct depuis un contrôleur, par exemple. Sans lui,
 * l'événement serait purement et simplement ignoré : la notification
 * apparaîtrait dans le centre de notifications mais ne partirait jamais, sans
 * la moindre trace expliquant pourquoi.
 *
 * <p>Rien n'est relancé en cas d'échec : la notification reste consultable dans
 * le centre de notifications, ce qui suffit. Une nouvelle tentative des heures
 * plus tard ferait vibrer un téléphone pour un fait déjà connu.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationEventListener {

    private final PousserNotificationUseCase pousserNotificationUseCase;

    @Async(NotificationAsyncConfig.EXECUTOR)
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void onNotificationCreee(NotificationCreeeEvent event) {
        try {
            pousserNotificationUseCase.execute(event.notificationId());
        } catch (Exception e) {
            // Hors transaction et hors requête : personne au-dessus pour
            // rattraper. On trace et on continue.
            log.error("Échec de l'envoi push de la notification {} : {}",
                    event.notificationId(), e.getMessage(), e);
        }
    }
}
