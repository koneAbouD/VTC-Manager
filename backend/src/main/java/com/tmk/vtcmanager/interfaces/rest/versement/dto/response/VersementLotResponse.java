package com.tmk.vtcmanager.interfaces.rest.versement.dto.response;

import java.util.List;
import java.util.UUID;

/**
 * Ce qu'est devenu chaque versement du lot. Toujours un 200 : c'est le détail
 * qui dit ce qui est passé et ce qui a été refusé, motif à afficher tel quel.
 */
public record VersementLotResponse(
        int reussis,
        int echecs,
        List<ResultatResponse> resultats
) {
    public record ResultatResponse(
            Long ligneRecetteId,
            Long ligneCotisationId,
            boolean succes,
            UUID versementId,
            String message,
            /** Écritures produites par un versement accepté, pour le reçu PDF. */
            List<Long> operationIds
    ) {}
}
