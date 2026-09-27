package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.ResultatAnnulationLot;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.util.ArrayList;
import java.util.List;

/**
 * Annule d'un geste les cotisations restées ouvertes d'une période, typiquement
 * après un arrêté de compte : le dépôt a été rendu, le reste impayé est
 * abandonné. Un seul motif pour tout le lot.
 *
 * <p><b>Sans transaction englobante, volontairement</b> (même patron que
 * {@link CreateEncaissementsCotisationLotUseCase}) : chaque ligne passe par
 * {@link AnnulerLigneCotisationUseCase} et sa propre transaction. Une ligne qui
 * détient encore du fonds est refusée seule, les autres sont annulées.
 */
@Slf4j
@RequiredArgsConstructor
public class AnnulerLignesCotisationLotUseCase {

    private final AnnulerLigneCotisationUseCase annulerLigneUseCase;

    public List<ResultatAnnulationLot> executer(List<Long> ligneIds, String motif) {
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        List<ResultatAnnulationLot> resultats = new ArrayList<>();
        for (Long id : ligneIds.stream().distinct().toList()) {
            try {
                annulerLigneUseCase.executer(id, motif);
                resultats.add(ResultatAnnulationLot.reussi(id));
            } catch (RuntimeException e) {
                log.warn("Annulation en lot refusée sur la ligne de cotisation {} : {}", id, e.toString());
                String message = e.getMessage();
                resultats.add(ResultatAnnulationLot.echec(id,
                        message == null || message.isBlank() ? "Annulation refusée." : message));
            }
        }
        return resultats;
    }
}
