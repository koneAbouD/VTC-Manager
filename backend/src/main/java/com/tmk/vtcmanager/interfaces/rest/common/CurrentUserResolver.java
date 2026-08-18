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
 *
 * <p>C'est aussi ce qui cadre les routes « /moi » : l'identité vient du jeton
 * et jamais du client, personne n'y lit donc la fiche d'un autre.
 */
@Component
public class CurrentUserResolver {

    public String keycloakUserIdOrThrow() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken jwtAuth)) {
            throw new RoleInsufficientException("anonyme", "AUTHENTIFIE");
        }
        String keycloakUserId = jwtAuth.getToken().getSubject();
        // Un jeton sans sujet ne désigne personne : mieux vaut le refuser que
        // laisser un `null` désigner une fiche au hasard plus bas.
        if (keycloakUserId == null || keycloakUserId.isBlank()) {
            throw new RoleInsufficientException("anonyme", "AUTHENTIFIE");
        }
        return keycloakUserId;
    }
}
