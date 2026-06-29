package com.tmk.vtcmanager.infrastructure.event;

import com.tmk.vtcmanager.application.domain.vehicule.event.VehiculeStatutDirtyEvent;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

/**
 * Adaptateur du port {@link VehiculeStatutEventPublisher} vers le mécanisme
 * d'événements applicatifs in-process de Spring. L'événement est traité de
 * façon synchrone, dans la transaction du use case émetteur (cohérence forte).
 */
@Component
@RequiredArgsConstructor
public class VehiculeStatutEventPublisherAdapter implements VehiculeStatutEventPublisher {

    private final ApplicationEventPublisher eventPublisher;

    @Override
    public void publishStatutDirty(Long vehiculeId) {
        if (vehiculeId == null) return;
        eventPublisher.publishEvent(new VehiculeStatutDirtyEvent(vehiculeId));
    }
}
