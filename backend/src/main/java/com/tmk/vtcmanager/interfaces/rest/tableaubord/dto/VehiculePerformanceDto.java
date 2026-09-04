package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;

/** Véhicule au palmarès de la période, mesuré à sa marge nette. */
public record VehiculePerformanceDto(
        Long vehiculeId,
        String immatriculation,
        BigDecimal produits,
        BigDecimal marge,
        BigDecimal margeNette,
        long joursImmobilisation
) {}
