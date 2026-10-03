package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;

import java.math.BigDecimal;
import java.time.LocalDate;

/** Créance laissée ouverte par l'arrêté, datée jusqu'à la fin de sa période. */
public record DetteRestanteArreteResponse(
        TypeDocumentCreance document,
        Long documentId,
        /** Null : dette du véhicule sans chauffeur rattaché. */
        Long chauffeurId,
        Long vehiculeId,
        String immatriculation,
        LocalDate dateDocument,
        /** Ce que le document réclamait à l'origine. */
        BigDecimal montantDu,
        /** Ce qu'il doit encore après l'arrêté. */
        BigDecimal reste
) {}
