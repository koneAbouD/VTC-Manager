package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.services.VerrouArreteService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

/**
 * Remet en circulation une ligne de recette annulée à tort.
 *
 * <p>La ligne retrouve le statut que dictent ses versements — en attente si
 * rien n'a été encaissé, partiellement encaissée sinon — et son marquage
 * d'annulation s'efface : la créance redevient exigible du chauffeur.
 *
 * <p>Tant que les livres sont ouverts, et pas au-delà : une fois la période
 * clôturée, les états du mois ont été arrêtés sans cette créance. L'y remettre
 * après coup les ferait mentir, et c'est une écriture du mois courant — non une
 * retouche du passé — qui doit alors porter la correction.
 */
@RequiredArgsConstructor
public class RestaurerLigneRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;
    private final VerrouArreteService verrouArreteService;

    @Transactional
    public LigneRecette executer(Long id) {
        LigneRecette ligne = ligneRecetteRepository.findById(id)
                .orElseThrow(() -> new LigneRecetteNotFoundException(id));

        if (ligne.getStatut() != StatutLigneRecette.ANNULEE) {
            throw new IllegalStateException("Cette ligne n'est pas annulée : rien à restaurer.");
        }
        verrouArreteService.verifier(ligne.getDateRecette());

        ligne.restaurer();
        return ligneRecetteRepository.save(ligne);
    }
}
