package com.tmk.vtcmanager.interfaces.rest.selfservice;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

/**
 * Résout le chauffeur courant à partir du JWT (claim {@code sub} = keycloakUserId).
 *
 * Point de sécurité central de l'app self-service : l'identité du chauffeur provient
 * du token, jamais d'un paramètre client — ce qui exclut tout accès aux données d'autrui.
 */
@Component
@RequiredArgsConstructor
public class CurrentChauffeurResolver {

    private final ChauffeurRepository chauffeurRepository;

    public Chauffeur resolveOrThrow() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken jwtAuth)) {
            throw new RoleInsufficientException("anonyme", "CHAUFFEUR");
        }
        String keycloakUserId = jwtAuth.getToken().getSubject();
        // Résolution primaire par le lien Keycloak (sub) ; repli par téléphone
        // (preferred_username = username Keycloak = téléphone canonique) au cas où
        // le lien keycloak_user_id ne serait pas encore posé en base.
        return chauffeurRepository.findByKeycloakUserId(keycloakUserId)
                .or(() -> {
                    String username = jwtAuth.getToken().getClaimAsString("preferred_username");
                    return username == null ? java.util.Optional.empty()
                            : chauffeurRepository.findByTelephone(username);
                })
                .orElseThrow(() -> new RoleInsufficientException(keycloakUserId, "CHAUFFEUR"));
    }
}
