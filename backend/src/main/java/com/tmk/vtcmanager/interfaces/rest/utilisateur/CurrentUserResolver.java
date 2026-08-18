package com.tmk.vtcmanager.interfaces.rest.utilisateur;

import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

/**
 * Résout l'identifiant Keycloak ({@code sub}) du compte connecté.
 *
 * Même garde-fou que {@code CurrentChauffeurResolver} côté self-service : sur
 * les routes « /moi », l'identité vient du jeton et jamais du client — un
 * gestionnaire ne peut donc pas lire ni modifier la fiche d'un autre en
 * glissant un identifiant dans la requête.
 */
@Component
public class CurrentUserResolver {

    public String idOrThrow() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken jwtAuth)) {
            throw new RoleInsufficientException("anonyme", "GESTIONNAIRE");
        }
        String keycloakUserId = jwtAuth.getToken().getSubject();
        if (keycloakUserId == null || keycloakUserId.isBlank()) {
            throw new RoleInsufficientException("anonyme", "GESTIONNAIRE");
        }
        return keycloakUserId;
    }
}
