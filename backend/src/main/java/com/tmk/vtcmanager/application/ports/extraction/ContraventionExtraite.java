package com.tmk.vtcmanager.application.ports.extraction;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;

/**
 * Une contravention brute telle qu'extraite d'un relevé PDF, avant résolution
 * du véhicule et rattachement du chauffeur.
 */
public record ContraventionExtraite(
        String numeroContravention,
        String codeInfraction,
        String libelleInfraction,
        LocalDate dateInfraction,
        LocalTime heureInfraction,
        Integer vitesseRelevee,
        String lieuInfraction,
        String debiteur,
        BigDecimal montant
) {}
