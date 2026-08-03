package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.ports.persistence.NotificationRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

/** Flux du centre de notifications d'un compte. */
@RequiredArgsConstructor
public class GetNotificationsUseCase {

    /**
     * Le centre de notifications se consulte, il ne s'archive pas : au-delà de
     * quelques dizaines d'entrées, plus personne ne remonte. Ce plafond évite
     * d'avoir à paginer un écran qu'on parcourt d'un coup de pouce.
     */
    private static final int LIMITE_MAX = 100;
    private static final int LIMITE_DEFAUT = 50;

    private final NotificationRepository repository;

    public List<Notification> execute(String keycloakUserId, Integer limite) {
        int taille = limite == null ? LIMITE_DEFAUT : Math.clamp(limite, 1, LIMITE_MAX);
        return repository.findByDestinataire(keycloakUserId, taille);
    }

    public long compterNonLues(String keycloakUserId) {
        return repository.compterNonLues(keycloakUserId);
    }
}
