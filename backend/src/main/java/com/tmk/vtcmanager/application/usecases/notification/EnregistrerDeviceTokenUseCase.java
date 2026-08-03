package com.tmk.vtcmanager.application.usecases.notification;

import com.tmk.vtcmanager.application.domain.notification.DeviceToken;
import com.tmk.vtcmanager.application.ports.persistence.DeviceTokenRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDateTime;

/**
 * Enregistre l'appareil d'un utilisateur, à la connexion comme à chaque
 * rafraîchissement du jeton par FCM.
 */
@RequiredArgsConstructor
public class EnregistrerDeviceTokenUseCase {

    private final DeviceTokenRepository repository;

    /**
     * Le jeton appartient à l'appareil, pas au compte : s'il est déjà connu, la
     * ligne existante change de propriétaire au lieu d'être dupliquée. C'est ce
     * qui évite qu'un chauffeur ayant prêté son téléphone continue d'y recevoir
     * ses notifications après que quelqu'un d'autre s'y est connecté.
     */
    public DeviceToken execute(DeviceToken demande) {
        demande.validate();

        DeviceToken aEnregistrer = repository.findByToken(demande.getToken())
                .map(existant -> {
                    existant.setKeycloakUserId(demande.getKeycloakUserId());
                    existant.setPlateforme(demande.getPlateforme());
                    existant.setApplication(demande.getApplication());
                    existant.setActif(true);
                    return existant;
                })
                .orElse(demande);

        aEnregistrer.setActif(true);
        aEnregistrer.setVuLe(LocalDateTime.now());
        return repository.save(aEnregistrer);
    }
}
