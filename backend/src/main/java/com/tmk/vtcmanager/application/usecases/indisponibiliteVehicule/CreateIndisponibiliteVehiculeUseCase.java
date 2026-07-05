package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class CreateIndisponibiliteVehiculeUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VehiculeStatutEventPublisher vehiculeStatutEventPublisher;

    @Transactional
    public IndisponibiliteVehicule execute(IndisponibiliteVehicule indisponibilite) {
        if (indisponibilite.getVehicule() == null || indisponibilite.getVehicule().getId() == null) {
            throw new IllegalArgumentException(
                    "Un véhicule est obligatoire pour une indisponibilité véhicule.");
        }
        indisponibilite.validerPourCreation();
        indisponibilite.initializeDefaults();
        IndisponibiliteVehicule saved = indisponibiliteVehiculeRepository.save(indisponibilite);

        // Le véhicule peut devenir IMMOBILISE si la période couvre aujourd'hui.
        vehiculeStatutEventPublisher.publishStatutDirty(saved.getVehiculeId());
        return saved;
    }
}
