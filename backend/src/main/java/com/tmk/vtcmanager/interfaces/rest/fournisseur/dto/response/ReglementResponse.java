package com.tmk.vtcmanager.interfaces.rest.fournisseur.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Un règlement passé sur une facture fournisseur. */
public record ReglementResponse(
        Long operationId,
        String reference,
        LocalDate date,
        BigDecimal montant,
        String modePaiement,
        String commentaire,
        /** Règlement contre-passé : il ne compte plus. */
        boolean extourne
) {}
