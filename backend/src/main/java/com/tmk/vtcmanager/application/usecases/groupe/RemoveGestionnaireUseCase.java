package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class RemoveGestionnaireUseCase {

    private final GroupeVehiculeRepository groupeVehiculeRepository;

    public GroupeVehicule execute(Long groupeId) {
        GroupeVehicule groupe = groupeVehiculeRepository.findById(groupeId)
                .orElseThrow(() -> ResourceNotFoundException.of("Groupe", groupeId));
        groupe.setGestionnaire(null);
        return groupeVehiculeRepository.save(groupe);
    }
}