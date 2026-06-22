package com.tmk.vtcmanager.application.usecases.groupe;

import com.tmk.vtcmanager.application.ports.persistence.GroupeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class DeleteGroupeUseCase {

    private final GroupeVehiculeRepository groupeVehiculeRepository;

    public void execute(Long id) {
        if (!groupeVehiculeRepository.existsById(id)) {
            throw new jakarta.persistence.EntityNotFoundException("Groupe introuvable : " + id);
        }
        groupeVehiculeRepository.deleteById(id);
    }
}