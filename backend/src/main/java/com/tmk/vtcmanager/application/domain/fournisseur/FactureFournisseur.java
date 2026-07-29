package com.tmk.vtcmanager.application.domain.fournisseur;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * Facture reçue d'un fournisseur.
 *
 * <p>C'est elle qui porte la charge, à sa date — pas son règlement. Le paiement
 * n'est plus qu'un mouvement de trésorerie qui vient solder la dette ; sans
 * cela, une facture de mars réglée en avril pèserait sur avril.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FactureFournisseur {

    private Long id;
    private String reference;
    private Fournisseur fournisseur;
    /** Numéro porté par la pièce du fournisseur. */
    private String numeroPiece;
    private CategorieOperation categorie;
    /** Véhicule concerné, quand la charge lui est imputable. */
    private Vehicule vehicule;
    /** Date de la facture : elle date la charge. */
    private LocalDate dateFacture;
    private LocalDate dateEcheance;
    private BigDecimal montant;
    private BigDecimal montantPaye;
    private StatutFactureFournisseur statut;
    private String description;

    private String motifAnnulation;
    private LocalDateTime annuleLe;
    private String annulePar;

    /** Ce qui reste à payer, jamais négatif. */
    public BigDecimal restantDu() {
        if (statut == StatutFactureFournisseur.ANNULEE) return BigDecimal.ZERO;
        BigDecimal paye = montantPaye != null ? montantPaye : BigDecimal.ZERO;
        BigDecimal reste = montant.subtract(paye);
        return reste.signum() > 0 ? reste : BigDecimal.ZERO;
    }

    /** Échue et non soldée à la date donnée. */
    public boolean estEnRetard(LocalDate date) {
        return statut.estOuverte() && dateEcheance != null && dateEcheance.isBefore(date);
    }

    /** Recalcule le statut depuis le montant réglé. */
    public void recalculerStatut() {
        if (statut == StatutFactureFournisseur.ANNULEE) return;
        BigDecimal paye = montantPaye != null ? montantPaye : BigDecimal.ZERO;
        if (paye.compareTo(montant) >= 0) {
            statut = StatutFactureFournisseur.PAYEE;
        } else if (paye.signum() > 0) {
            statut = StatutFactureFournisseur.PARTIELLEMENT_PAYEE;
        } else {
            statut = StatutFactureFournisseur.A_PAYER;
        }
    }
}
