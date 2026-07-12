package com.tmk.vtcmanager.application.domain.cotisation;

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
    /** Arrêté de compte ayant soldé la ligne (RESTITUEE). Null tant qu'elle n'est pas restituée. */
    private Long arreteId;
    @Builder.Default
    private List<EncaissementCotisation> encaissements = new ArrayList<>();

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

    /** Vrai si un versement a déjà été enregistré sur la ligne. */
    public boolean aDesVersements() {
        return (montantEncaisse != null && montantEncaisse.compareTo(BigDecimal.ZERO) > 0)
                || (encaissements != null && !encaissements.isEmpty());
    }

    /** Passe la ligne en ANNULEE avec son motif (validation dans le use case). */
    public void annuler(String motif) {
        this.statut = StatutLigneCotisation.ANNULEE;
        this.motifAnnulation = motif;
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
