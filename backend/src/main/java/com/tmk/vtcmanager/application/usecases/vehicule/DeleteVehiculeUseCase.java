package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class DeleteVehiculeUseCase {

    private final VehiculeRepository vehiculeRepository;

    @Transactional
    public void execute(Long id) {
        vehiculeRepository.findById(id)
                .orElseThrow(() -> new VehiculeNotFoundException(id));
        vehiculeRepository.deleteById(id);
    }
}
