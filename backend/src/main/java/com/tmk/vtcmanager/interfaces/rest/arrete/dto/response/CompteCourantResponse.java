package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

import java.math.BigDecimal;

/** Solde de compte courant d'un tiers (chauffeur ou véhicule). */
public record CompteCourantResponse(
        Long tiersId,
        String libelle,
        BigDecimal fondsCotisation,
        BigDecimal du0a7Jours,
        BigDecimal du8a30Jours,
        BigDecimal duPlus30Jours,
        BigDecimal totalCreances,
        BigDecimal net
) {}
