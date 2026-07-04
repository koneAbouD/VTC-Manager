package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;

public record CreanceChauffeurResponse(
        Long chauffeurId,
        String nom,
        String prenom,
        int nbLignes,
        BigDecimal du0a7Jours,
        BigDecimal du8a30Jours,
        BigDecimal duPlus30Jours,
        BigDecimal total
) {}
