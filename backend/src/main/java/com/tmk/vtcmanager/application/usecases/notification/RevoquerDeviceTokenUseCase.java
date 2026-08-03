package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.ports.persistence.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Coupe l'envoi vers un appareil, à la déconnexion.
 *
 * <p>Appelé par l'application avant la révocation de sa session : sans cela,
 * l'appareil continuerait de recevoir les notifications d'un compte qui n'y est
 * plus connecté.
 */
@Slf4j
@RequiredArgsConstructor
public class RevoquerDeviceTokenUseCase {

    private final DeviceTokenRepository repository;

    /**
     * La révocation est vérifiée : on ne désactive le jeton que s'il appartient
     * bien à l'appelant. Sinon n'importe quel compte authentifié pourrait faire
     * taire les notifications d'un autre en devinant son jeton.
     */
    public void execute(String keycloakUserId, String token) {
        repository.findByToken(token).ifPresent(existant -> {
            if (!existant.getKeycloakUserId().equals(keycloakUserId)) {
                log.warn("Tentative de révocation d'un jeton d'appareil appartenant à un autre compte");
                return;
            }
            repository.desactiverToken(token);
        });
    }
}
