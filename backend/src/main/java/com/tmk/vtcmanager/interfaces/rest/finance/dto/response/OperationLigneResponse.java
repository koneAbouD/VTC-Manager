package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record OperationLigneResponse(
        Long id,
        String type,
        String description,
        String chauffeurNom,
        String vehiculeLabel,
        BigDecimal montant,
        LocalDate date
) {}
