package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Vue "rapport financier" de la période : totaux revenus/dépenses avec
 * variation sur le mois précédent, répartitions (revenus par chauffeur ou
 * véhicule selon {@code groupBy}, dépenses par catégorie) et la liste des
 * opérations terminées. Les agrégats excluent les catégories HORS_RESULTAT
 * (comptes de tiers) pour rester alignés sur le compte de résultat.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RapportFinancier {

    private BigDecimal totalRevenus;
    private BigDecimal totalDepenses;
    private BigDecimal variationRevenusPct;
    private BigDecimal variationDepensesPct;
    private String groupBy;
    private List<LigneRepartition> breakdownRevenus;
    private List<LigneRepartition> breakdownDepenses;
    private List<LigneOperation> listeOperations;

    /** Une part de la répartition (revenus ou dépenses). */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class LigneRepartition {
        private String label;
        private BigDecimal montant;
        private BigDecimal pourcentage;
    }

    /** Une opération de la liste détaillée. */
    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class LigneOperation {
        private Long id;
        private String type;
        private String description;
        private String chauffeurNom;
        private String vehiculeLabel;
        private BigDecimal montant;
        private LocalDate date;
    }
}
