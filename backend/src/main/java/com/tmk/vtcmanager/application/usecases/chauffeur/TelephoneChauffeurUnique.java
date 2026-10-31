package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;

import java.util.Objects;

/**
 * Le téléphone est l'identifiant de connexion du chauffeur (username Keycloak,
 * OTP) : deux fiches ne peuvent pas le partager, sinon la seconde se rattache
 * au compte de la première et l'enregistrement échoue sur l'unicité du lien.
 */
final class TelephoneChauffeurUnique {

    private TelephoneChauffeurUnique() {
    }

    /** @param chauffeurId fiche en cours de modification, {@code null} à la création */
    static void verifier(ChauffeurRepository chauffeurRepository, String telephone, Long chauffeurId) {
        if (telephone == null || telephone.isBlank()) {
            return;
        }
        chauffeurRepository.findByTelephone(telephone)
                .filter(autre -> !Objects.equals(autre.getId(), chauffeurId))
                .ifPresent(autre -> {
                    throw new ResourceAlreadyExistsException("Le numéro " + telephone
                            + " est déjà utilisé par le chauffeur "
                            + autre.getPrenom() + " " + autre.getNom() + ".");
                });
    }
}
