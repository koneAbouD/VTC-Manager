package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Bilan de gestion dérivé (photo des stocks à une date) : chaque poste est
 * un calcul, aucune écriture. La situation nette est obtenue par différence
 * (équilibre par construction — suffisant en gestion, pas en fiscal).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BilanGestion {

    private LocalDate date;

    // Actif
    private BigDecimal tresorerie;
    private BigDecimal creancesChauffeurs;
    /** Σ valeur nette comptable des véhicules (prix d'achat − amortissement couru). */
    private BigDecimal immobilisationsNettes;
    private BigDecimal totalActif;

    // Passif
    private BigDecimal detteEtatContraventions;
    /** totalActif − dettes. */
    private BigDecimal situationNette;
}
