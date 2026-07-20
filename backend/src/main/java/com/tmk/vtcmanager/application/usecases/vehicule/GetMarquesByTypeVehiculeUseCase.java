package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Marque;
import com.tmk.vtcmanager.application.ports.persistence.MarqueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetMarquesByTypeVehiculeUseCase {

    private final MarqueRepository marqueRepository;

    /**
     * Marques d'un type de véhicule, destinées à la <b>sélection</b> (formulaire
     * véhicule) : on ne retourne que les marques <b>actives</b>. Le paramétrage,
     * lui, liste toutes les marques via l'endpoint de base.
     */
    public List<Marque> execute(Long typeId) {
        return marqueRepository.findAll().stream()
                .filter(Marque::isActif)
                .filter(marque -> marque.getType() != null && marque.getType().getId().equals(typeId))
                .toList();
    }
}
