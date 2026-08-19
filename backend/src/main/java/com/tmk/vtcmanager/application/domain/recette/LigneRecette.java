package com.tmk.vtcmanager.application.domain.recette;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
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
    /**
     * Moment de l'annulation. Sans lui, une ligne annulée disparaîtrait des
     * états reconstitués à une date où elle était encore due.
     */
    private LocalDateTime annuleLe;
    @Builder.Default
    private List<Encaissement> encaissements = new ArrayList<>();
    /**
     * Renseigné à la lecture seulement : faux si un arrêté — période close,
     * caisse comptée — interdit désormais de restaurer cet élément annulé. Le
     * client s'en sert pour ne pas proposer une action vouée au refus.
     */
    private Boolean restaurable;

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

    /**
     * Vrai si un versement <em>qui tient encore</em> a été enregistré sur la
     * ligne. Un encaissement extourné ne compte pas : il reste au journal, mais
     * l'argent a été rendu — la ligne est de nouveau annulable.
     */
    public boolean aDesVersements() {
        return (montantEncaisse != null && montantEncaisse.compareTo(BigDecimal.ZERO) > 0)
                || (encaissements != null
                        && encaissements.stream().anyMatch(e -> e.getAnnuleLe() == null));
    }

    /** Passe la ligne en ANNULEE avec son motif (validation dans le use case). */
    public void annuler(String motif) {
        this.statut = StatutLigneRecette.ANNULEE;
        this.motifAnnulation = motif;
        this.annuleLe = LocalDateTime.now();
    }

    /**
     * Rend une ligne annulée à l'état où elle était due.
     *
     * <p>Le statut n'est pas « celui d'avant » — il se déduit de ce qui a
     * effectivement été encaissé : rien, la ligne est de nouveau en attente ;
     * une partie, elle est partiellement encaissée. Le marquage d'annulation
     * s'efface : sans cela, la ligne resterait absente des états reconstitués
     * après sa date d'annulation, alors qu'elle est de nouveau exigible.
     */
    public void restaurer() {
        BigDecimal encaisse = montantEncaisse != null ? montantEncaisse : BigDecimal.ZERO;
        if (montantAttendu != null && encaisse.compareTo(montantAttendu) >= 0) {
            this.statut = StatutLigneRecette.ENCAISSE;
        } else if (encaisse.compareTo(BigDecimal.ZERO) > 0) {
            this.statut = StatutLigneRecette.PARTIELLEMENT_ENCAISSE;
        } else {
            this.statut = StatutLigneRecette.EN_ATTENTE;
        }
        this.motifAnnulation = null;
        this.annuleLe = null;
    }
}
