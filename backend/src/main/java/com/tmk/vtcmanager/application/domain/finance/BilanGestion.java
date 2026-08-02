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
    /** Créances brutes, avant dépréciation. */
    private BigDecimal creancesChauffeurs;
    /** Dépréciation des créances selon leur ancienneté (politique paramétrable). */
    private BigDecimal provisionCreances;
    /** creancesChauffeurs − provisionCreances : c'est ce montant qui entre à l'actif. */
    private BigDecimal creancesNettes;
    /** Σ valeur nette comptable des véhicules (prix d'achat − amortissement couru). */
    private BigDecimal immobilisationsNettes;
    private BigDecimal totalActif;

    // Passif
    private BigDecimal detteEtatContraventions;
    /** Reste dû aux fournisseurs sur les factures non soldées. */
    private BigDecimal dettesFournisseurs;
    /**
     * Cotisations encaissées et non encore restituées : un dépôt détenu pour le
     * compte des chauffeurs, donc une dette. Porté pour son montant brut, sans
     * compensation avec les créances qui figurent à l'actif.
     */
    private BigDecimal depotsCotisations;
    /** totalActif − dettes (État + fournisseurs + dépôts de cotisation). */
    private BigDecimal situationNette;
}
