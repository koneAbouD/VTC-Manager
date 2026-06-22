package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetAllTypesVehiculesUseCase {

    private final TypeVehiculeRepository typeVehiculeRepository;

    public List<TypeVehicule> execute() {
        return typeVehiculeRepository.findAll();
    }
}
