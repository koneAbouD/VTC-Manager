package com.tmk.vtcmanager.interfaces.rest.arrete.dto.response;

import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Arrêté de compte : en-tête + lignes snapshot + règlements. Sert aussi à l'aperçu. */
public record ArreteResponse(
        Long id,
        PerimetreArrete perimetre,
        Long perimetreId,
        String perimetreLibelle,
        LocalDate periodeDebut,
        LocalDate periodeFin,
        LocalDate dateArrete,
        String reference,
        String statut,
        String motifAnnulation,
        BigDecimal totalRestitue,
        List<LigneArreteResponse> lignes,
        List<ReglementArreteResponse> reglements
) {}
