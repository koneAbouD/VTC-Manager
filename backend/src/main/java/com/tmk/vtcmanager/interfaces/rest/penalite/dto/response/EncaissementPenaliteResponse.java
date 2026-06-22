package com.tmk.vtcmanager.interfaces.rest.penalite.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record EncaissementPenaliteResponse(
        Long id,
        Long lignePenaliteId,
        Long operationFinanciereId,
        BigDecimal montant,
        String modeEncaissement,
        LocalDate dateEncaissement,
        String reference,
        String commentaire
) {}
