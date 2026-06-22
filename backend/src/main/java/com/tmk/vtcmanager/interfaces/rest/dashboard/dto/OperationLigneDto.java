package com.tmk.vtcmanager.interfaces.rest.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;

public record OperationLigneDto(
        Long id,
        String type,
        String description,
        String chauffeurNom,
        String vehiculeLabel,
        BigDecimal montant,
        LocalDate date
) {}
