package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CheckGroupeUtilisationUseCase {

    private final GroupeVehiculeRepository groupeVehiculeRepository;
    private final VehiculeRepository vehiculeRepository;

    public long countVehicules(Long groupeId) {
        if (!groupeVehiculeRepository.existsById(groupeId)) {
            throw new jakarta.persistence.EntityNotFoundException("Groupe introuvable : " + groupeId);
        }
        return vehiculeRepository.countByGroupeId(groupeId);
    }
}
