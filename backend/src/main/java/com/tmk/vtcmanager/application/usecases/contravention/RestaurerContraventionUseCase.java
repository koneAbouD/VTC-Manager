package com.tmk.vtcmanager.application.usecases.contravention;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.ContraventionRepository;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Remet en circulation une contravention annulée à tort.
 *
 * <p>Elle retrouve le statut que dicte ce que le chauffeur a versé — en attente
 * si rien n'a été payé — et son marquage d'annulation s'efface : la créance
 * redevient exigible.
 *
 * <p>Refusé une fois la période de l'infraction clôturée : les états du mois ont
 * été arrêtés sans cette créance, l'y remettre après coup les ferait mentir.
 */
@RequiredArgsConstructor
public class RestaurerContraventionUseCase {

    private final ContraventionRepository contraventionRepository;
    private final VerrouArreteService verrouArreteService;

    @Transactional
    public Contravention execute(Long id) {
        Contravention contravention = contraventionRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Contravention", id));

        if (!contravention.estAnnulee()) {
            throw new IllegalStateException(
                    "Cette contravention n'est pas annulée : rien à restaurer.");
        }
        verrouArreteService.verifier(contravention.getDateInfraction());

        contravention.restaurer();
        return contraventionRepository.save(contravention);
    }
}
