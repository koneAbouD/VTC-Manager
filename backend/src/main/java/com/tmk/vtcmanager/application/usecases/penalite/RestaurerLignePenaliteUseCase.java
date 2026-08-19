package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Remet en circulation une pénalité annulée à tort.
 *
 * <p>Une amende retrouve le statut que dictent ses versements — en attente si
 * rien n'a été encaissé ; les autres sanctions repartent en attente
 * d'exécution, la sanction n'ayant pas été purgée.
 *
 * <p>Refusé une fois la période de la faute clôturée : les états du mois ont
 * été arrêtés sans cette créance.
 */
@RequiredArgsConstructor
public class RestaurerLignePenaliteUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;
    private final VerrouArreteService verrouArreteService;

    @Transactional
    public LignePenalite executer(Long id) {
        LignePenalite ligne = lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));

        if (ligne.getStatut() != StatutLignePenalite.ANNULEE) {
            throw new IllegalStateException("Cette pénalité n'est pas annulée : rien à restaurer.");
        }
        // La faute date la créance ; à défaut, le jour où la pénalité a été
        // générée fait foi.
        verrouArreteService.verifier(
                ligne.getDateFaute() != null ? ligne.getDateFaute() : ligne.getDateGeneration());

        ligne.restaurer();
        return lignePenaliteRepository.save(ligne);
    }
}
