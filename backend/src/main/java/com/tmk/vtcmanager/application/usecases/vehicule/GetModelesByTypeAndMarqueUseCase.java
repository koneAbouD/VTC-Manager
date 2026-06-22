package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.vehicule.Modele;
import com.tmk.vtcmanager.application.ports.persistence.ModeleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetModelesByTypeAndMarqueUseCase {

    private final ModeleRepository modeleRepository;

    public List<Modele> execute(Long typeId, Long marqueId) {
        // Filtrer les modèles par type et marque
        return modeleRepository.findAll().stream()
                .filter(modele -> modele.getType() != null && modele.getType().getId().equals(typeId))
                .filter(modele -> modele.getMarque() != null && modele.getMarque().getId().equals(marqueId))
                .toList();
    }

    public List<Modele> executeByType(Long typeId) {
        // Filtrer les modèles par type uniquement
        return modeleRepository.findAll().stream()
                .filter(modele -> modele.getType() != null && modele.getType().getId().equals(typeId))
                .toList();
    }

    public List<Modele> executeByMarque(Long marqueId) {
        // Filtrer les modèles par marque uniquement
        return modeleRepository.findByMarqueId(marqueId);
    }
}
