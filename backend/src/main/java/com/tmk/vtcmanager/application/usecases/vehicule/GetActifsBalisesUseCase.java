package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;
import com.tmk.vtcmanager.application.ports.persistence.BaliseRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Balises <b>actives uniquement</b>, triées par identifiant — destinées à la
 * sélection (formulaire véhicule). Le paramétrage consomme la liste complète
 * via {@link GetAllBalisesUseCase}.
 */
@Service
@RequiredArgsConstructor
public class GetActifsBalisesUseCase {

    private final BaliseRepository baliseRepository;

    public List<Balise> execute() {
        return baliseRepository.findAllActifs();
    }
}
