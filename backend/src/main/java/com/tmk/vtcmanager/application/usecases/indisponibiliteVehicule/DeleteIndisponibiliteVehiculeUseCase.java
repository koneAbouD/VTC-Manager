package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteIndisponibiliteVehiculeUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VehiculeStatutEventPublisher vehiculeStatutEventPublisher;

    @Transactional
    public void execute(Long id) {
        IndisponibiliteVehicule existing = indisponibiliteVehiculeRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité véhicule", id));
        Long vehiculeId = existing.getVehiculeId();

        indisponibiliteVehiculeRepository.deleteById(id);

        // La suppression peut faire sortir le véhicule d'IMMOBILISE.
        vehiculeStatutEventPublisher.publishStatutDirty(vehiculeId);
    }
}
