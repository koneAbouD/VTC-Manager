package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response;

import java.util.List;

/**
 * Ce qu'est devenu chaque ligne du lot. Le lot n'étant pas un tout ou rien, la
 * réponse est toujours un 200 : c'est le détail qui dit ce qui est passé et ce
 * qui a été refusé, avec le motif à afficher tel quel.
 */
public record EncaissementCotisationLotResponse(
        int reussis,
        int echecs,
        List<ResultatLigneResponse> resultats
) {
    public record ResultatLigneResponse(
            Long ligneId,
            boolean succes,
            Long encaissementId,
            String message
    ) {}
}
