package com.tmk.vtcmanager.infrastructure.event;

import com.tmk.vtcmanager.application.domain.vehicule.event.VehiculeStatutDirtyEvent;
import com.tmk.vtcmanager.application.usecases.vehicule.RecomputeVehiculeStatusUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;

/**
 * Listener unique des changements de signal véhicule : délègue le recalcul du
 * statut au use case dédié. Synchrone (même transaction que l'émetteur) : si la
 * transaction échoue, le recalcul est annulé avec le reste.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class VehiculeStatutEventListener {

    private final RecomputeVehiculeStatusUseCase recomputeVehiculeStatusUseCase;

    @EventListener
    public void onStatutDirty(VehiculeStatutDirtyEvent event) {
        log.debug("Recalcul du statut du véhicule {}", event.vehiculeId());
        recomputeVehiculeStatusUseCase.execute(event.vehiculeId());
    }
}
