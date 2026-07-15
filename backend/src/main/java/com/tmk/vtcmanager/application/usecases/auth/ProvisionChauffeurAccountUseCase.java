package com.tmk.vtcmanager.application.usecases.auth;

import com.tmk.vtcmanager.application.domain.auth.RegisterRequest;
import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.common.PhoneNumberNormalizer;
import com.tmk.vtcmanager.application.domain.common.SecretGenerator;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.util.List;

/**
 * Provisionne le compte d'accès (Keycloak) d'un chauffeur pour l'app self-service.
 * Crée l'utilisateur (username = téléphone canonique, rôle CHAUFFEUR, secret aléatoire)
 * et enregistre le lien {@code keycloakUserId} sur le chauffeur. Idempotent.
 */
@Slf4j
@RequiredArgsConstructor
public class ProvisionChauffeurAccountUseCase {

    public static final String ROLE_CHAUFFEUR = "CHAUFFEUR";
    /** Domaine des e-mails synthétiques quand le chauffeur n'en a pas. */
    private static final String EMAIL_SYNTHETIQUE_DOMAINE = "@chauffeur.tmk.local";

    private final ChauffeurRepository chauffeurRepository;
    private final KeycloakAdminPort keycloakAdminPort;

    /** E-mail réel du chauffeur, ou e-mail synthétique dérivé du username (profil Keycloak complet). */
    private String emailPour(Chauffeur chauffeur, String username) {
        String email = chauffeur.getEmail();
        if (email != null && !email.isBlank()) {
            return email;
        }
        return username + EMAIL_SYNTHETIQUE_DOMAINE;
    }

    public Chauffeur execute(Long chauffeurId) {
        return execute(chauffeurId, null);
    }

    /**
     * @param motDePasseInitial mot de passe initial optionnel (active tout de
     *        suite la connexion par mot de passe) ; {@code null} → secret aléatoire.
     */
    public Chauffeur execute(Long chauffeurId, String motDePasseInitial) {
        Chauffeur chauffeur = chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> ResourceNotFoundException.of("Chauffeur", chauffeurId));

        if (chauffeur.getTelephone() == null || chauffeur.getTelephone().isBlank()) {
            throw new IllegalStateException(
                    "Le chauffeur doit avoir un numéro de téléphone pour créer un compte.");
        }
        String username = PhoneNumberNormalizer.canonique(chauffeur.getTelephone());
        String email = emailPour(chauffeur, username);

        if (chauffeur.getKeycloakUserId() != null) {
            // Déjà provisionné : compléter le profil (e-mail) et réparer l'état,
            // puis (re)poser le mot de passe si fourni.
            keycloakAdminPort.updateUser(chauffeur.getKeycloakUserId(), UserInfo.builder()
                    .username(username)
                    .email(email)
                    .firstName(chauffeur.getPrenom())
                    .lastName(chauffeur.getNom())
                    .build());
            keycloakAdminPort.markAccountReady(chauffeur.getKeycloakUserId());
            if (motDePasseInitial != null && !motDePasseInitial.isBlank()) {
                keycloakAdminPort.resetPassword(chauffeur.getKeycloakUserId(), motDePasseInitial);
            }
            return chauffeur;
        }

        // Pas de lien en base : un compte Keycloak peut déjà exister sous ce
        // username (ex. provisioning antérieur ayant échoué après la création,
        // ou création manuelle). On le (re)lie plutôt que d'échouer en 409.
        String keycloakUserId = keycloakAdminPort.findUserIdByUsername(username).orElse(null);

        if (keycloakUserId != null) {
            keycloakAdminPort.updateUser(keycloakUserId, UserInfo.builder()
                    .username(username)
                    .email(email)
                    .firstName(chauffeur.getPrenom())
                    .lastName(chauffeur.getNom())
                    .build());
            keycloakAdminPort.assignRealmRole(keycloakUserId, ROLE_CHAUFFEUR);
            keycloakAdminPort.markAccountReady(keycloakUserId);
            if (motDePasseInitial != null && !motDePasseInitial.isBlank()) {
                keycloakAdminPort.resetPassword(keycloakUserId, motDePasseInitial);
            }
            log.info("Compte chauffeur existant (re)lié : chauffeurId={}, keycloakUserId={}",
                    chauffeurId, keycloakUserId);
        } else {
            String motDePasse = (motDePasseInitial != null && !motDePasseInitial.isBlank())
                    ? motDePasseInitial
                    : SecretGenerator.motDePasseEphemere();

            UserInfo user = keycloakAdminPort.createUser(RegisterRequest.builder()
                    .username(username)
                    .email(email)
                    .password(motDePasse)
                    .firstName(chauffeur.getPrenom())
                    .lastName(chauffeur.getNom())
                    .phone(username)
                    .roles(List.of(ROLE_CHAUFFEUR))
                    .build());
            keycloakAdminPort.markAccountReady(user.getId());
            keycloakUserId = user.getId();
            log.info("Compte chauffeur provisionné : chauffeurId={}, keycloakUserId={}",
                    chauffeurId, keycloakUserId);
        }

        chauffeur.setKeycloakUserId(keycloakUserId);
        return chauffeurRepository.save(chauffeur);
    }
}
