package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.TextesNotification;
import com.tmk.vtcmanager.application.ports.notification.NotificationEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import lombok.RequiredArgsConstructor;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Optional;

/**
 * Point d'entrée des use cases métier qui veulent notifier quelqu'un.
 *
 * <p>La notification est enregistrée dans la transaction de l'appelant : elle
 * naît et meurt avec l'opération qui la motive. L'envoi, lui, est seulement
 * demandé — il aura lieu après la validation de cette transaction, de sorte
 * qu'une opération annulée ne notifie personne.
 */
@RequiredArgsConstructor
public class CreerNotificationUseCase {

    /**
     * Au-delà, deux notifications de même clé décrivent deux gestes distincts.
     * Cinq minutes couvrent largement des requêtes qui se suivent — un
     * encaissement rapide en enchaîne deux en une seconde — sans étouffer le
     * second passage d'un chauffeur venu verser dans l'après-midi.
     */
    private static final Duration FENETRE_REGROUPEMENT = Duration.ofMinutes(5);

    private final NotificationRepository repository;
    private final NotificationEventPublisher eventPublisher;

    public Notification execute(Notification notification) {
        return execute(notification, null);
    }

    /**
     * Enregistre la notification, ou réécrit celle qui porte déjà la même clé de
     * regroupement.
     *
     * <p>Le regroupement sert un geste unique que le système traite en plusieurs
     * fois : l'utilisateur a versé une somme, il n'a pas à recevoir deux
     * messages parce que le logiciel l'a répartie entre une recette et une
     * cotisation. Le message existant prend alors la rédaction
     * {@code siDejaNotifie} — au pluriel — et <b>aucun nouvel envoi n'est
     * demandé</b> : le téléphone a déjà sonné pour ce geste, et le centre de
     * notifications montre une ligne à jour plutôt que deux.
     *
     * <p>Une notification déjà lue n'est jamais réécrite : son destinataire en a
     * pris connaissance, la modifier sous ses yeux reviendrait à réécrire le
     * passé.
     */
    public Notification execute(Notification notification, TextesNotification siDejaNotifie) {
        notification.validate();
        notification.setLue(false);
        notification.setDetail(tronquer(notification.getDetail()));

        Optional<Notification> aRegrouper = notification.getCleGroupe() == null || siDejaNotifie == null
                ? Optional.empty()
                : repository.findNonLueParCleGroupe(
                        notification.getDestinataireKeycloakId(),
                        notification.getCleGroupe(),
                        LocalDateTime.now().minus(FENETRE_REGROUPEMENT));

        if (aRegrouper.isPresent()) {
            Notification cumul = aRegrouper.get();
            cumul.setTitre(siDejaNotifie.titre());
            cumul.setCorps(siDejaNotifie.corps());
            // Le détail ne se remplace pas, il s'ajoute : le corps annonce qu'il
            // y a eu plusieurs faits, le détail dit lesquels. C'est tout
            // l'intérêt d'un centre de notifications qu'on relit.
            cumul.setDetail(cumulerDetail(cumul.getDetail(), notification.getDetail()));
            return repository.save(cumul);
        }

        Notification enregistree = repository.save(notification);
        eventPublisher.publierNotificationCreee(enregistree.getId());
        return enregistree;
    }

    /**
     * Empile les détails, en s'arrêtant à ce que la colonne accepte.
     *
     * <p>Tronquer plutôt que laisser la base refuser : la notification est déjà
     * enregistrée dans la transaction de l'opération métier, et un versement ne
     * saurait échouer parce que son récit est trop long.
     */
    private static String cumulerDetail(String precedent, String nouveau) {
        if (precedent == null || precedent.isBlank()) return tronquer(nouveau);
        if (nouveau == null || nouveau.isBlank()) return tronquer(precedent);
        return tronquer(precedent + "\n" + nouveau);
    }

    /** Longueur de {@code notifications.detail}. */
    private static final int DETAIL_MAX = 300;

    private static String tronquer(String detail) {
        if (detail == null || detail.length() <= DETAIL_MAX) return detail;
        return detail.substring(0, DETAIL_MAX - 1) + "…";
    }
}
