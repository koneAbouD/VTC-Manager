package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Enregistre une nouvelle vidange pour un véhicule. Chaque enregistrement crée
 * une entrée d'historique ; la plus récente fait office de « dernière vidange »
 * et sa cible de « prochaine vidange ».
 */
@RequiredArgsConstructor
public class CreateVidangeUseCase {

    private final VidangeRepository vidangeRepository;
    private final VehiculeRepository vehiculeRepository;

    @Transactional
    public Vidange execute(Long vehiculeId, Vidange vidange) {
        vehiculeRepository.findById(vehiculeId)
                .orElseThrow(() -> new VehiculeNotFoundException(vehiculeId));

        vidange.setVehiculeId(vehiculeId);
        vidange.valider();
        return vidangeRepository.save(vidange);
    }
}
