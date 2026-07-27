package com.tmk.vtcmanager.infrastructure.config.security;

import org.springframework.data.domain.AuditorAware;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * Auteur des écritures, tiré du jeton Keycloak.
 *
 * <p>Le {@code JwtAuthConverter} place le {@code preferred_username} comme nom
 * du principal : c'est ce libellé, lisible par un humain, qui est archivé sur
 * chaque écriture financière. Hors requête HTTP (batchs, schedulers), l'auteur
 * est {@link #AUTEUR_SYSTEME} — jamais vide, pour qu'une écriture ne puisse pas
 * exister sans origine identifiée.
 */
@Component
public class SecurityAuditorAware implements AuditorAware<String> {

    public static final String AUTEUR_SYSTEME = "system";

    @Override
    public Optional<String> getCurrentAuditor() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated() || auth.getName() == null
                || auth.getName().isBlank() || "anonymousUser".equals(auth.getName())) {
            return Optional.of(AUTEUR_SYSTEME);
        }
        return Optional.of(auth.getName());
    }
}
