package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class GetGroupeByIdUseCase {

    private final GroupeVehiculeRepository groupeVehiculeRepository;
    private final VehiculeRepository vehiculeRepository;

    public GroupeVehicule execute(Long id) {
        GroupeVehicule groupe = groupeVehiculeRepository.findById(id)
                .orElseThrow(() -> new jakarta.persistence.EntityNotFoundException("Groupe introuvable : " + id));
        groupe.setNbVehicules((int) vehiculeRepository.countByGroupeId(id));
        return groupe;
    }
}