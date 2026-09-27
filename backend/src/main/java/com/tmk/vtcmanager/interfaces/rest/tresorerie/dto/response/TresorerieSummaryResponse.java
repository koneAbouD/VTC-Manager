package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response;

import java.math.BigDecimal;
import java.util.List;

public record TresorerieSummaryResponse(
        List<CompteTresorerieResponse> comptes,
        BigDecimal totalTresorerie,
        /** Contraventions encaissées auprès des chauffeurs, non reversées à l'État. */
        BigDecimal aReverserEtat,
        /** Cotisations encaissées pas encore rendues : argent détenu pour les chauffeurs. */
        BigDecimal depotsCotisations,
        /**
         * Ce qui appartient réellement à l'entreprise : total − dépôts − à
         * reverser à l'État. Négatif, la trésorerie ne couvre plus ce qu'elle
         * doit rendre.
         */
        BigDecimal disponibleReel
) {}
