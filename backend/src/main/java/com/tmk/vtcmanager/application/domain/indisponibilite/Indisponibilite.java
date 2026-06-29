package com.tmk.vtcmanager.application.domain.indisponibilite;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Période d'indisponibilité d'un chauffeur (congé, maladie, suspension…),
 * avec éventuellement un chauffeur remplaçant assigné sur la période.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Indisponibilite {

    private Long id;

    /** Chauffeur indisponible. */
    private Chauffeur chauffeur;

    /** Chauffeur remplaçant (optionnel). */
    private Chauffeur chauffeurRemplacant;

    private LocalDate dateDebut;

    /** Date de fin (optionnelle : indisponibilité ouverte si null). */
    private LocalDate dateFin;

    /** Motif de l'indisponibilité (ex. Congé, Maladie, Suspension…). */
    private String motif;

    private String commentaire;

    private IndisponibiliteStatut statut;

    /** Calcule le statut courant à partir des dates. */
    public IndisponibiliteStatut computeStatutFromDates() {
        final LocalDate today = LocalDate.now();
        if (dateDebut == null) return IndisponibiliteStatut.PLANIFIEE;
        if (dateFin != null && dateFin.isBefore(today)) return IndisponibiliteStatut.TERMINEE;
        if (!dateDebut.isAfter(today)) return IndisponibiliteStatut.EN_COURS;
        return IndisponibiliteStatut.PLANIFIEE;
    }

    public void initializeDefaults() {
        if (this.statut == null) this.statut = computeStatutFromDates();
    }

    /** Clôture l'indisponibilité (fin anticipée ou normale). */
    public void terminer() {
        this.statut = IndisponibiliteStatut.TERMINEE;
        if (this.dateFin == null || this.dateFin.isAfter(LocalDate.now())) {
            this.dateFin = LocalDate.now();
        }
    }

    /** Annule l'indisponibilité (sans effet sur le programme). */
    public void annuler() {
        this.statut = IndisponibiliteStatut.ANNULEE;
    }

    /** Cohérence des dates (fin ≥ début). */
    public void validerCoherence() {
        if (dateDebut == null) {
            throw new IllegalArgumentException("La date de début est obligatoire.");
        }
        if (dateFin != null && dateFin.isBefore(dateDebut)) {
            throw new IllegalArgumentException(
                    "La date de fin doit être postérieure ou égale à la date de début.");
        }
    }

    /**
     * Validation à la création : une indisponibilité ne peut pas être définie
     * sur une date ou une période antérieure à aujourd'hui.
     */
    public void validerPourCreation() {
        validerCoherence();
        if (dateDebut.isBefore(LocalDate.now())) {
            throw new IllegalArgumentException(
                    "L'indisponibilité ne peut pas être définie sur une date ou une période antérieure à aujourd'hui.");
        }
    }
}
