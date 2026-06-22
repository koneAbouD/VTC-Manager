package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CreateGroupeUseCase {

    private final GroupeVehiculeRepository groupeVehiculeRepository;

    public GroupeVehicule execute(GroupeVehicule groupe) {
        if (groupeVehiculeRepository.existsByNom(groupe.getNom())) {
            throw ResourceAlreadyExistsException.of("Groupe", "nom", groupe.getNom());
        }
        return groupeVehiculeRepository.save(groupe);
    }
}