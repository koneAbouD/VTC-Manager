package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response;

import com.tmk.vtcmanager.application.domain.cotisation.ResultatAnnulationLot;

import java.util.List;

/**
 * Verdict ligne par ligne d'une annulation de masse. Toujours 200 : c'est le
 * détail qui dit ce qui a été annulé et ce qui a été refusé.
 */
public record AnnulationCotisationLotResponse(
        int reussis,
        int echecs,
        List<ResultatAnnulationLot> resultats
) {
    public static AnnulationCotisationLotResponse from(List<ResultatAnnulationLot> resultats) {
        int reussis = (int) resultats.stream().filter(ResultatAnnulationLot::succes).count();
        return new AnnulationCotisationLotResponse(reussis, resultats.size() - reussis, resultats);
    }
}
