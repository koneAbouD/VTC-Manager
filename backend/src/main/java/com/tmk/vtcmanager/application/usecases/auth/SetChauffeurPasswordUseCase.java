package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import lombok.RequiredArgsConstructor;

/**
 * Définit (ou change) le mot de passe d'un chauffeur, activant ainsi le mode de
 * connexion par mot de passe. Appelé par le chauffeur lui-même (scope /api/me)
 * après une première connexion OTP.
 */
@RequiredArgsConstructor
public class SetChauffeurPasswordUseCase {

    private static final int LONGUEUR_MIN = 6;

    private final ChauffeurRepository chauffeurRepository;
    private final KeycloakAdminPort keycloakAdminPort;

    public void execute(Long chauffeurId, String motDePasse) {
        if (motDePasse == null || motDePasse.length() < LONGUEUR_MIN) {
            throw new IllegalArgumentException(
                    "Le mot de passe doit contenir au moins " + LONGUEUR_MIN + " caractères.");
        }
        Chauffeur chauffeur = chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> ResourceNotFoundException.of("Chauffeur", chauffeurId));
        if (chauffeur.getKeycloakUserId() == null) {
            throw new IllegalStateException("Ce chauffeur n'a pas de compte d'accès.");
        }
        keycloakAdminPort.resetPassword(chauffeur.getKeycloakUserId(), motDePasse);
    }
}
