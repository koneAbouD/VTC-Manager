package com.tmk.vtcmanager.interfaces.rest.dashboard.dto;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record DashboardSummaryResponse(
        // Carte revenus
        BigDecimal totalRevenusMois,
        BigDecimal totalRecettesMois,
        BigDecimal totalDepensesMois,
        BigDecimal variationRevenusPct,
        BigDecimal variationRecettesPct,
        BigDecimal variationDepensesPct,
        int nbRecettesEncaisseesMois,
        int nbChauffeursAvecRecette,
        String periodeLabel,

        // Stat cards
        int nbChauffeursActifs,
        int nbChauffeursTotal,
        int nbVehiculesEnService,
        int nbVehiculesTotal,
        LocalDate dateAujourdhui,

        // Alertes
        int nbMaintenancesEnCours,
        int nbDocumentsExpires,

        // Dernières opérations
        List<OperationLigneDto> dernieresOperations
) {}
