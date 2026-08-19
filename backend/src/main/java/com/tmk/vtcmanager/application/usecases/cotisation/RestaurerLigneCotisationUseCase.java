package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Remet en circulation une ligne de cotisation annulée à tort.
 *
 * <p>La ligne retrouve le statut que dictent ses versements — en attente si
 * rien n'a été encaissé, partiellement encaissée sinon — et son marquage
 * d'annulation s'efface : le dépôt redevient dû.
 *
 * <p>Refusé une fois la période clôturée : les états du mois ont été arrêtés
 * sans cette créance, l'y remettre après coup les ferait mentir.
 */
@RequiredArgsConstructor
public class RestaurerLigneCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;
    private final VerrouArreteService verrouArreteService;

    @Transactional
    public LigneCotisation executer(Long id) {
        LigneCotisation ligne = ligneCotisationRepository.findById(id)
                .orElseThrow(() -> new LigneCotisationNotFoundException(id));

        if (ligne.getStatut() != StatutLigneCotisation.ANNULEE) {
            throw new IllegalStateException("Cette ligne n'est pas annulée : rien à restaurer.");
        }
        verrouArreteService.verifier(ligne.getDateCotisation());

        ligne.restaurer();
        return ligneCotisationRepository.save(ligne);
    }
}
