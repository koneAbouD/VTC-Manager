package com.tmk.vtcmanager.application.domain.cotisation;

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
public class LigneCotisation {

    private Long id;
    private Long vehiculeId;
    private String vehiculeImmatriculation;
    private Long chauffeurId;
    private String chauffeurNom;
    private LocalDate dateCotisation;
    private String nomCotisation;
    private BigDecimal montantDu;
    private BigDecimal montantEncaisse;
    private StatutLigneCotisation statut;
    /** Motif saisi lors de l'annulation de la ligne (obligatoire à l'annulation). */
    private String motifAnnulation;
    /**
     * Moment de l'annulation. Sans lui, une ligne annulée disparaîtrait des
     * états reconstitués à une date où elle était encore due.
     */
    private LocalDateTime annuleLe;
    /** Arrêté de compte ayant soldé la ligne (RESTITUEE). Null tant qu'elle n'est pas restituée. */
    private Long arreteId;
    @Builder.Default
    private List<EncaissementCotisation> encaissements = new ArrayList<>();
    /**
     * Renseigné à la lecture seulement : faux si un arrêté — période close,
     * caisse comptée — interdit désormais de restaurer cet élément annulé. Le
     * client s'en sert pour ne pas proposer une action vouée au refus.
     */
    private Boolean restaurable;

    public void recalculerStatutEtMontant() {
        BigDecimal total = encaissements.stream()
                .map(EncaissementCotisation::getMontant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        this.montantEncaisse = total;

        int cmp = total.compareTo(montantDu);
        if (cmp >= 0) {
            this.statut = StatutLigneCotisation.ENCAISSE;
        } else if (total.compareTo(BigDecimal.ZERO) > 0) {
            this.statut = StatutLigneCotisation.PARTIELLEMENT_ENCAISSE;
        } else {
            this.statut = StatutLigneCotisation.EN_ATTENTE;
        }
    }

    public boolean estActive() {
        return statut == StatutLigneCotisation.EN_ATTENTE
                || statut == StatutLigneCotisation.PARTIELLEMENT_ENCAISSE;
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
        this.statut = StatutLigneCotisation.ANNULEE;
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
        if (montantDu != null && encaisse.compareTo(montantDu) >= 0) {
            this.statut = StatutLigneCotisation.ENCAISSE;
        } else if (encaisse.compareTo(BigDecimal.ZERO) > 0) {
            this.statut = StatutLigneCotisation.PARTIELLEMENT_ENCAISSE;
        } else {
            this.statut = StatutLigneCotisation.EN_ATTENTE;
        }
        this.motifAnnulation = null;
        this.annuleLe = null;
    }

    /** Passe la ligne en RESTITUEE en la rattachant à l'arrêté qui l'a soldée. */
    public void restituer(Long arreteId) {
        this.statut = StatutLigneCotisation.RESTITUEE;
        this.arreteId = arreteId;
    }

    public BigDecimal montantRestant() {
        BigDecimal encaisse = montantEncaisse != null ? montantEncaisse : BigDecimal.ZERO;
        return montantDu.subtract(encaisse).max(BigDecimal.ZERO);
    }

    /**
     * Normalise le nom de cotisation pour le stockage et la comparaison :
     * trim, minuscules puis <b>première lettre en majuscule</b> (ex. « ENTRETIEN »
     * ou « entretien » → « Entretien »). La comparaison ré-applique cette
     * normalisation à la valeur stockée, la cohérence est donc préservée.
     */
    public static String normaliserNom(String nom) {
        if (nom == null) return null;
        String base = nom.trim().toLowerCase();
        if (base.isEmpty()) return base;
        return Character.toUpperCase(base.charAt(0)) + base.substring(1);
    }
}
