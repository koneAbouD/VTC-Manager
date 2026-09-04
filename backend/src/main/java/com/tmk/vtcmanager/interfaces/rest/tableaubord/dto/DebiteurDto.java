package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;

/** Chauffeur débiteur, avec la part ancienne de son encours. */
public record DebiteurDto(
        Long chauffeurId,
        String nom,
        int nbLignes,
        BigDecimal total,
        BigDecimal plus30Jours
) {}
