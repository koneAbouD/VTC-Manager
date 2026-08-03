package com.tmk.vtcmanager.interfaces.rest.common;

import com.tmk.vtcmanager.application.exception.RoleInsufficientException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

/**
 * Identifiant Keycloak ({@code sub}) du compte appelant, quel que soit son rôle.
 *
 * <p>Pendant du {@code CurrentChauffeurResolver}, mais sans passage par la base :
 * les gestionnaires n'ont pas de ligne en base, ils n'existent que dans
 * Keycloak. C'est précisément pourquoi les notifications s'adressent à un
 * {@code sub} plutôt qu'à un chauffeur.
 */
@Component
public class CurrentUserResolver {

    public String keycloakUserIdOrThrow() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken jwtAuth)) {
            throw new RoleInsufficientException("anonyme", "AUTHENTIFIE");
        }
        return jwtAuth.getToken().getSubject();
    }
}
