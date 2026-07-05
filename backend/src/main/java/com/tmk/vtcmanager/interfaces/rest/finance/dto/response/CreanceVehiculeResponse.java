package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;

public record CreanceVehiculeResponse(
        Long vehiculeId,
        String immatriculation,
        String marque,
        String modele,
        int nbLignes,
        BigDecimal du0a7Jours,
        BigDecimal du8a30Jours,
        BigDecimal duPlus30Jours,
        BigDecimal total
) {}
