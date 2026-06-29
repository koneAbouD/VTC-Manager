package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.StatutVehicule;
import com.tmk.vtcmanager.application.ports.persistence.StatutVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetAllStatutsVehiculeUseCase {

    private final StatutVehiculeRepository statutVehiculeRepository;

    public List<StatutVehicule> execute() {
        return statutVehiculeRepository.findAll();
    }
}
