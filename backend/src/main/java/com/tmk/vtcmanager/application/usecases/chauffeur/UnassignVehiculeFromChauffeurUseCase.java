package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class UnassignVehiculeFromChauffeurUseCase {

    private final ChauffeurRepository chauffeurRepository;
    private final VehiculeRepository vehiculeRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;

    @Transactional
    public Chauffeur execute(Long chauffeurId) {
        Chauffeur chauffeur = chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurId));

        Vehicule vehicule = chauffeur.getVehicule();

        if (vehicule != null) {
            final Long vehiculeId = vehicule.getId();
            programmeTravailRepository.findByVehiculeId(vehiculeId).ifPresent(programme -> {
                programme.getChauffeurs().removeIf(pc -> chauffeurId.equals(pc.getChauffeurId()));
                programmeTravailRepository.save(programme);
            });
        }

        chauffeur.unassignVehicule();
        return chauffeurRepository.save(chauffeur);
    }
}
