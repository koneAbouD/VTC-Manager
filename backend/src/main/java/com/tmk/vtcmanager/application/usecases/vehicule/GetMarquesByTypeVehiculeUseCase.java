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

    public List<Marque> execute(Long typeId) {
        // Pour l'instant, nous allons chercher toutes les marques et filtrer par type
        // Dans une implémentation optimisée, nous pourrions ajouter une méthode findByTypeId dans le repository
        return marqueRepository.findAll().stream()
                .filter(marque -> marque.getType() != null && marque.getType().getId().equals(typeId))
                .toList();
    }
}
