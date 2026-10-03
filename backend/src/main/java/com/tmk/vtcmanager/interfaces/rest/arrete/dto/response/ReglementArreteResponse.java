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
        /** Reste dû sur les créances datées jusqu'à la fin de période, reporté sur l'arrêté suivant. */
        BigDecimal reliquatReporte,
        /** Reste dû des périodes précédentes, repris par cet arrêté. */
        BigDecimal reliquatAnterieur,
        ModePaiement modePaiement,
        Long compteTresorerieId,
        Long operationDecaissementId
) {}
