package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

/**
 * Historique des vidanges d'un véhicule, de la plus récente à la plus ancienne.
 */
@RequiredArgsConstructor
public class GetVidangesByVehiculeUseCase {

    private final VidangeRepository vidangeRepository;

    public List<Vidange> execute(Long vehiculeId) {
        return vidangeRepository.findByVehiculeId(vehiculeId);
    }
}
