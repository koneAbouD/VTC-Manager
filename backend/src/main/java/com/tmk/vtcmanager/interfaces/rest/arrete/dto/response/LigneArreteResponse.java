package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;

import java.math.BigDecimal;

/** Ligne snapshot d'un arrêté : cotisation (CREDIT) ou créance compensée (DEBIT). */
public record LigneArreteResponse(
        TypeDocumentCreance document,
        Long documentId,
        Long chauffeurId,
        Long vehiculeId,
        String immatriculation,
        BigDecimal montant,
        SensArrete sens
) {}
