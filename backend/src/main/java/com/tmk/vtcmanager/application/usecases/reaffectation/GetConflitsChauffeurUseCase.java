package com.tmk.vtcmanager.application.usecases.reaffectation;

import com.tmk.vtcmanager.application.domain.coherence.ConflitChauffeurJour;
import com.tmk.vtcmanager.application.ports.persistence.CoherenceGenerationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Les journées où un chauffeur porte des créances sur plusieurs véhicules.
 *
 * <p>La génération quotidienne ne bloque pas ce cas — une recette non créée
 * serait de l'argent que personne ne réclame — mais elle le signale. La
 * notification prévient le jour même ; cette lecture-ci permet à l'écran
 * Recettes de le rappeler tant que rien n'a été tranché, sur toute la période
 * qu'il affiche.
 */
@RequiredArgsConstructor
public class GetConflitsChauffeurUseCase {

    private final CoherenceGenerationRepository coherenceRepository;

    @Transactional(readOnly = true)
    public List<ConflitChauffeurJour> executer(LocalDate debut, LocalDate fin) {
        if (debut == null || fin == null) {
            throw new IllegalArgumentException("La période à contrôler est obligatoire.");
        }
        if (fin.isBefore(debut)) {
            throw new IllegalArgumentException("La fin de période ne peut précéder son début.");
        }
        return coherenceRepository.chauffeursSurPlusieursVehicules(debut, fin);
    }
}
