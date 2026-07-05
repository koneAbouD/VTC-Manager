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

    private String commentaire;

    /** Motif saisi lors de l'annulation de la ligne (obligatoire à l'annulation). */
    private String motifAnnulation;

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

    /** Vrai si un versement a déjà été enregistré sur la ligne. */
    public boolean aDesVersements() {
        return (montantEncaisse != null && montantEncaisse.compareTo(BigDecimal.ZERO) > 0)
                || (encaissements != null && !encaissements.isEmpty());
    }

    /** Passe la ligne en ANNULEE avec son motif (validation dans le use case). */
    public void annuler(String motif) {
        this.statut = StatutLignePenalite.ANNULEE;
        this.motifAnnulation = motif;
    }
}
