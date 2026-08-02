package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Suppression d'une contravention.
 *
 * <p>Réservée à la saisie qui n'a jamais rien produit. Dès qu'un mouvement
 * d'argent s'y rattache — versement du chauffeur ou reversement à l'État —
 * l'effacer ferait disparaître la contrepartie d'écritures qui, elles, restent
 * au journal. Ces cas passent par l'annulation, qui conserve la trace.
 */
@RequiredArgsConstructor
public class DeleteContraventionUseCase {

    private final ContraventionRepository contraventionRepository;

    @Transactional
    public void execute(Long id) {
        Contravention contravention = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));

        if (contravention.aDesVersements() || contravention.getDateReversement() != null) {
            throw new IllegalStateException("Cette contravention a donné lieu à un mouvement "
                    + "d'argent : elle ne se supprime pas, annulez-la pour en garder la trace.");
        }

        contraventionRepository.deleteById(id);
    }
}
