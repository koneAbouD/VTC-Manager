package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;
import com.tmk.vtcmanager.application.ports.persistence.TypeVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Types de véhicule <b>actifs uniquement</b>, triés par nom — destinés à la
 * sélection (formulaires). Le paramétrage consomme la liste complète via
 * {@link GetAllTypesVehiculesUseCase}.
 */
@Service
@RequiredArgsConstructor
public class GetActifsTypesVehiculesUseCase {

    private final TypeVehiculeRepository typeVehiculeRepository;

    public List<TypeVehicule> execute() {
        return typeVehiculeRepository.findAllActifs();
    }
}
