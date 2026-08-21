package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Ligne snapshot d'un arrêté : cotisation (CREDIT) ou créance compensée (DEBIT). */
public record LigneArreteResponse(
        TypeDocumentCreance document,
        Long documentId,
        Long chauffeurId,
        Long vehiculeId,
        String immatriculation,
        /** Jour couvert par le document (recette, cotisation, faute, infraction). */
        LocalDate dateDocument,
        BigDecimal montant,
        /** Restant dû du document, hors part compensée ici. Null sur un arrêté enregistré. */
        BigDecimal restant,
        SensArrete sens
) {}
