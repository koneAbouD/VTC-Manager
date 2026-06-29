package com.tmk.vtcmanager.infrastructure.event;

import com.tmk.vtcmanager.application.domain.chauffeur.event.ChauffeurStatutDirtyEvent;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

/**
 * Adaptateur du port {@link ChauffeurStatutEventPublisher} vers le mécanisme
 * d'événements applicatifs in-process de Spring. Traitement synchrone, dans la
 * transaction du use case émetteur (cohérence forte).
 */
@Component
@RequiredArgsConstructor
public class ChauffeurStatutEventPublisherAdapter implements ChauffeurStatutEventPublisher {

    private final ApplicationEventPublisher eventPublisher;

    @Override
    public void publishStatutDirty(Long chauffeurId) {
        if (chauffeurId == null) return;
        eventPublisher.publishEvent(new ChauffeurStatutDirtyEvent(chauffeurId));
    }
}
