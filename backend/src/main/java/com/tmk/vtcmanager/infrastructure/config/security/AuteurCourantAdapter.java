package com.tmk.vtcmanager.infrastructure.config.security;

import com.tmk.vtcmanager.application.ports.security.AuteurCourant;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * Adaptateur du port {@link AuteurCourant} sur le contexte de sécurité Spring —
 * même source que l'audit JPA, pour qu'un {@code created_by} et un
 * {@code annule_par} désignent toujours la même personne de la même façon.
 */
@Component
@RequiredArgsConstructor
public class AuteurCourantAdapter implements AuteurCourant {

    private final SecurityAuditorAware auditorAware;

    @Override
    public String nom() {
        return auditorAware.getCurrentAuditor().orElse(SecurityAuditorAware.AUTEUR_SYSTEME);
    }
}
