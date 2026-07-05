package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class TerminerIndisponibiliteVehiculeUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VehiculeStatutEventPublisher vehiculeStatutEventPublisher;

    @Transactional
    public IndisponibiliteVehicule execute(Long id) {
        IndisponibiliteVehicule existing = indisponibiliteVehiculeRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Indisponibilité véhicule", id));
        // terminer() borne la date de fin à aujourd'hui : dès demain le véhicule
        // n'est plus immobilisé par cette indisponibilité.
        existing.terminer();
        IndisponibiliteVehicule saved = indisponibiliteVehiculeRepository.save(existing);

        vehiculeStatutEventPublisher.publishStatutDirty(saved.getVehiculeId());
        return saved;
    }
}
