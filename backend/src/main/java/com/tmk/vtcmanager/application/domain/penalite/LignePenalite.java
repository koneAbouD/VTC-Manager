package com.tmk.vtcmanager.application.domain.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
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
public class LignePenalite {

    private Long id;
    private Long vehiculeId;
    private String vehiculeImmatriculation;
    private Long chauffeurId;
    private String chauffeurNomComplet;
    private Long penaliteTemplateId;
    private TypePenalite typePenalite;
    private TypeSanction typeSanction;

    private BigDecimal montant;
    private BigDecimal montantEncaisse;

    private Integer dureeSanctionSecondes;
    private Integer dureeImmobilisationMinutes;
    private LocalDateTime dateDebutImmobilisation;
    private LocalDateTime dateFinImmobilisation;

    private LocalDate dateGeneration;
    private LocalDate dateFaute;
    private Long ligneRecetteId;
    private StatutLignePenalite statut;

    @Builder.Default
    private List<EncaissementPenalite> encaissements = new ArrayList<>();
    /**
     * Renseigné à la lecture seulement : faux si un arrêté — période close,
     * caisse comptée — interdit désormais de restaurer cet élément annulé. Le
     * client s'en sert pour ne pas proposer une action vouée au refus.
     */
    private Boolean restaurable;

    private String commentaire;

    /** Motif saisi lors de l'annulation de la ligne (obligatoire à l'annulation). */
    private String motifAnnulation;
    /**
     * Moment de l'annulation. Sans lui, une ligne annulée disparaîtrait des
     * états reconstitués à une date où elle était encore due.
     */
    private LocalDateTime annuleLe;

    public boolean isEncaissable() {
        return TypeSanction.AMENDE.equals(typeSanction)
                && statut != StatutLignePenalite.ENCAISSEE
                && statut != StatutLignePenalite.ANNULEE;
    }

    public boolean isExecutable() {
        return TypeSanction.BUZZER.equals(typeSanction)
                && StatutLignePenalite.EN_ATTENTE.equals(statut);
    }

    public boolean isNotifiable() {
        return TypeSanction.AVERTISSEMENT.equals(typeSanction)
                && StatutLignePenalite.EN_ATTENTE.equals(statut);
    }

    public boolean isDemarrable() {
        return TypeSanction.IMMOBILISATION.equals(typeSanction)
                && StatutLignePenalite.EN_ATTENTE.equals(statut);
    }

    public boolean isLevable() {
        return TypeSanction.IMMOBILISATION.equals(typeSanction)
                && StatutLignePenalite.EN_COURS.equals(statut);
    }

    public void recalculerStatutAmende() {
        BigDecimal total = encaissements.stream()
                .map(EncaissementPenalite::getMontant)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
        this.montantEncaisse = total;

        int cmp = total.compareTo(montant);
        if (cmp >= 0) {
            this.statut = StatutLignePenalite.ENCAISSEE;
        } else if (total.compareTo(BigDecimal.ZERO) > 0) {
            this.statut = StatutLignePenalite.PARTIELLEMENT_ENCAISSEE;
        } else {
            this.statut = StatutLignePenalite.EN_ATTENTE;
        }
    }

    public BigDecimal montantRestant() {
        BigDecimal encaisse = montantEncaisse != null ? montantEncaisse : BigDecimal.ZERO;
        BigDecimal base = montant != null ? montant : BigDecimal.ZERO;
        return base.subtract(encaisse).max(BigDecimal.ZERO);
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
        this.statut = StatutLignePenalite.ANNULEE;
        this.motifAnnulation = motif;
        this.annuleLe = LocalDateTime.now();
    }

    /**
     * Rend une ligne annulée à l'état où elle était due.
     *
     * <p>Une amende retrouve le statut que dictent ses versements — aucun, elle
     * est de nouveau en attente. Les autres sanctions (buzzer, avertissement,
     * immobilisation) repartent en attente d'exécution : la sanction annulée
     * n'a pas été purgée, elle reste à appliquer.
     */
    public void restaurer() {
        BigDecimal encaisse = montantEncaisse != null ? montantEncaisse : BigDecimal.ZERO;
        boolean amende = TypeSanction.AMENDE.equals(typeSanction);
        if (amende && montant != null && encaisse.compareTo(montant) >= 0) {
            this.statut = StatutLignePenalite.ENCAISSEE;
        } else if (amende && encaisse.compareTo(BigDecimal.ZERO) > 0) {
            this.statut = StatutLignePenalite.PARTIELLEMENT_ENCAISSEE;
        } else {
            this.statut = StatutLignePenalite.EN_ATTENTE;
        }
        this.motifAnnulation = null;
        this.annuleLe = null;
    }
}
