package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

/**
 * Photo des états au moment de la clôture d'un mois.
 *
 * <p>Une fois la période close, c'est cette photo qui fait foi : elle ne bouge
 * plus, quoi qu'il advienne en amont (barème d'amortissement révisé, catégorie
 * reclassée, créance soldée). Sans elle, un état « publié » se réécrivait tout
 * seul et n'était opposable à personne.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EtatsCloture {

    private Long id;
    private Long cloturePeriodeId;
    private int annee;
    private int mois;

    // Compte de résultat, base caisse
    private BigDecimal produitsCaisse;
    private BigDecimal chargesVariables;
    private BigDecimal chargesFixes;
    private BigDecimal amortissements;
    /** Variation du stock de provision sur le mois (dotation, ou reprise si négative). */
    private BigDecimal dotationProvisions;
    private BigDecimal resultatCaisse;

    // Compte de résultat, base engagement
    private BigDecimal produitsEngagement;
    /**
     * Charges variables engagées sur le mois — factures partenaire reçues
     * comprises, réglées ou non. {@code null} sur les photos antérieures à
     * l'archivage des deux bases : la lecture retombe alors sur les charges
     * caisse.
     */
    private BigDecimal chargesVariablesEngagement;
    /** Charges fixes engagées sur le mois. Même convention de {@code null}. */
    private BigDecimal chargesFixesEngagement;
    private BigDecimal resultatEngagement;
    private BigDecimal pontCreances;

    // Bilan de gestion arrêté au dernier jour de la période
    private BigDecimal tresorerie;
    /** Créances brutes. */
    private BigDecimal creancesChauffeurs;
    /** Dépréciation appliquée à la date de clôture. */
    private BigDecimal provisionCreances;
    /** Montant retenu à l'actif : brutes − provision. */
    private BigDecimal creancesNettes;
    private BigDecimal immobilisationsNettes;
    private BigDecimal totalActif;
    private BigDecimal detteEtat;
    /** Reste dû aux fournisseurs au dernier jour de la période. */
    private BigDecimal dettesFournisseurs;
    /**
     * Cotisations détenues au dernier jour de la période, brutes de toute
     * compensation avec les créances des chauffeurs.
     */
    private BigDecimal depotsCotisations;
    private BigDecimal situationNette;

    /** Justification de la ligne « trésorerie », compte par compte. */
    private List<SoldeCompteCloture> soldes;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SoldeCompteCloture {
        private Long compteId;
        private String libelleCompte;
        private BigDecimal solde;
    }
}
