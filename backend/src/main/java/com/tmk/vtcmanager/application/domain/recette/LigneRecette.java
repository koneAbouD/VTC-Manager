package com.tmk.vtcmanager.application.domain.recette;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LigneRecette {

    private Long id;
    private Long vehiculeId;
    private String vehiculeImmatriculation;
    private Long chauffeurId;
    private String chauffeurNom;
    private LocalDate dateRecette;
    /** Null si typeRecette == MONTANT_REEL */
    private BigDecimal montantAttendu;
    private BigDecimal montantEncaisse;
    private StatutLigneRecette statut;
    /** Motif saisi lors de l'annulation de la ligne (obligatoire à l'annulation). */
    private String motifAnnulation;
    @Builder.Default
    private List<Encaissement> encaissements = new ArrayList<>();

    public void recalculerStatutEtMontant() {
        BigDecimal total = encaissements.stream()
                .map(Encaissement::getMontant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        this.montantEncaisse = total;

        if (montantAttendu == null) {
            // MONTANT_REEL : seul le bouton "Confirmer versement" bascule en ENCAISSE
            this.statut = total.compareTo(BigDecimal.ZERO) > 0
                    ? StatutLigneRecette.PARTIELLEMENT_ENCAISSE
                    : StatutLigneRecette.EN_ATTENTE;
        } else {
            // MONTANT_FIXE
            int cmp = total.compareTo(montantAttendu);
            if (cmp >= 0) {
                this.statut = StatutLigneRecette.ENCAISSE;
            } else if (total.compareTo(BigDecimal.ZERO) > 0) {
                this.statut = StatutLigneRecette.PARTIELLEMENT_ENCAISSE;
            } else {
                this.statut = StatutLigneRecette.EN_ATTENTE;
            }
        }
    }

    public boolean estActive() {
        return statut == StatutLigneRecette.EN_ATTENTE
                || statut == StatutLigneRecette.PARTIELLEMENT_ENCAISSE;
    }

    /** Vrai si un versement a déjà été enregistré sur la ligne. */
    public boolean aDesVersements() {
        return (montantEncaisse != null && montantEncaisse.compareTo(BigDecimal.ZERO) > 0)
                || (encaissements != null && !encaissements.isEmpty());
    }

    /** Passe la ligne en ANNULEE avec son motif (validation dans le use case). */
    public void annuler(String motif) {
        this.statut = StatutLigneRecette.ANNULEE;
        this.motifAnnulation = motif;
    }
}
