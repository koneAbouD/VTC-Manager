package com.tmk.vtcmanager.infrastructure.event;

import com.tmk.vtcmanager.application.domain.chauffeur.event.ChauffeurStatutDirtyEvent;
import com.tmk.vtcmanager.application.usecases.chauffeur.RecomputeChauffeurStatusUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Listener unique des changements de signal chauffeur : délègue le recalcul du
 * statut au use case dédié. Synchrone (même transaction que l'émetteur).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ChauffeurStatutEventListener {

    private final RecomputeChauffeurStatusUseCase recomputeChauffeurStatusUseCase;

    @EventListener
    public void onStatutDirty(ChauffeurStatutDirtyEvent event) {
        log.debug("Recalcul du statut du chauffeur {}", event.chauffeurId());
        recomputeChauffeurStatusUseCase.execute(event.chauffeurId());
    }
}
