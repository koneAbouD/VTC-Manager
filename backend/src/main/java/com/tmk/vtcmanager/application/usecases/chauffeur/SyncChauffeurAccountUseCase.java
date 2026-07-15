package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.common.PhoneNumberNormalizer;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.usecases.auth.ProvisionChauffeurAccountUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Maintient le compte Keycloak d'un chauffeur aligné sur sa fiche.
 *
 * - Chauffeur sans compte + téléphone présent → provisionne (crée l'utilisateur
 *   Keycloak, username = téléphone canonique, rôle CHAUFFEUR).
 * - Chauffeur déjà provisionné → met à jour username (téléphone), nom, prénom, email.
 *
 * Best-effort : une panne Keycloak ne doit pas bloquer la gestion des chauffeurs.
 * En cas d'échec on journalise ; l'écart se résorbe à la prochaine modification
 * (le compte manquant sera re-tenté tant que keycloakUserId est null).
 *
 * NB : le changement de username exige que le realm autorise l'édition du username
 * (paramètre Keycloak « Edit username »).
 */
@Slf4j
@RequiredArgsConstructor
public class SyncChauffeurAccountUseCase {

    private final KeycloakAdminPort keycloakAdminPort;
    private final ProvisionChauffeurAccountUseCase provisionChauffeurAccountUseCase;

    public void synchroniser(Chauffeur chauffeur) {
        if (chauffeur == null || chauffeur.getId() == null) {
            return;
        }
        String telephone = chauffeur.getTelephone();
        if (telephone == null || telephone.isBlank()) {
            // Pas de téléphone → pas de username possible, rien à synchroniser.
            return;
        }
        try {
            if (chauffeur.getKeycloakUserId() == null) {
                provisionChauffeurAccountUseCase.execute(chauffeur.getId());
            } else {
                keycloakAdminPort.updateUser(chauffeur.getKeycloakUserId(), UserInfo.builder()
                        .username(PhoneNumberNormalizer.canonique(telephone))
                        .email(chauffeur.getEmail())
                        .firstName(chauffeur.getPrenom())
                        .lastName(chauffeur.getNom())
                        .build());
            }
        } catch (Exception e) {
            log.warn("Synchronisation Keycloak du chauffeur {} échouée : {}",
                    chauffeur.getId(), e.getMessage());
        }
    }
}
