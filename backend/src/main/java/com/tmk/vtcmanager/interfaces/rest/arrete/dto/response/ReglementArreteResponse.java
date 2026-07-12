package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;

/** Règlement d'un arrêté pour un bénéficiaire chauffeur. */
public record ReglementArreteResponse(
        Long chauffeurId,
        String chauffeurNom,
        BigDecimal totalCotisations,
        BigDecimal totalCreancesCompensees,
        BigDecimal montantNet,
        BigDecimal reliquatReporte,
        ModePaiement modePaiement,
        Long compteTresorerieId,
        Long operationDecaissementId
) {}
