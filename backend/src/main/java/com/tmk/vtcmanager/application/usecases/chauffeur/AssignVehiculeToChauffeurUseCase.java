package com.tmk.vtcmanager.application.usecases.chauffeur;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.exception.ChauffeurNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class AssignVehiculeToChauffeurUseCase {

    private final ChauffeurRepository chauffeurRepository;
    private final VehiculeRepository vehiculeRepository;
    private final VehiculeStatutEventPublisher statutEventPublisher;

    @Transactional
    public Chauffeur execute(Long chauffeurId, Long vehiculeId) {
        Chauffeur chauffeur = chauffeurRepository.findById(chauffeurId)
                .orElseThrow(() -> new ChauffeurNotFoundException(chauffeurId));

        Vehicule vehicule = vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        chauffeur.assignVehicule(vehicule);
        Chauffeur saved = chauffeurRepository.save(chauffeur);

        // Le statut du véhicule (EN_SERVICE) est recalculé via l'événement.
        statutEventPublisher.publishStatutDirty(vehiculeId);
        return saved;
    }
}
