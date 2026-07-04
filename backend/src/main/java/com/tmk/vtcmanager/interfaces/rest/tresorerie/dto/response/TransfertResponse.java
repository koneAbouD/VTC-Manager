package com.tmk.vtcmanager.interfaces.rest.tresorerie.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record TransfertResponse(
        Long id,
        Long compteSourceId,
        Long compteDestinationId,
        BigDecimal montant,
        LocalDate dateTransfert,
        String commentaire
) {}
