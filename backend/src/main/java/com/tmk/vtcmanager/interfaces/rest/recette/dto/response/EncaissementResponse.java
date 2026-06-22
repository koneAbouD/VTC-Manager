package com.tmk.vtcmanager.interfaces.rest.recette.dto.response;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EncaissementResponse(
        Long id,
        Long ligneRecetteId,
        Long operationFinanciereId,
        BigDecimal montant,
        ModePaiement modeEncaissement,
        LocalDate dateEncaissement,
        String reference,
        String commentaire
) {}
