package com.tmk.vtcmanager.application.domain.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Période d'immobilisation d'un véhicule hors atelier (accident/sinistre, panne
 * en attente de pièces, immobilisation administrative ou juridique…). Symétrique
 * à l'indisponibilité chauffeur : pendant la période le véhicule est IMMOBILISE
 * et ne génère ni recette, ni cotisation, ni pénalité.
 * <p>
 * La maintenance planifiée reste gérée par son propre module ({@code EN_MAINTENANCE}).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class IndisponibiliteVehicule {

    private Long id;

    /** Véhicule immobilisé. */
    private Vehicule vehicule;

    private LocalDate dateDebut;

    /** Date de fin (optionnelle : immobilisation ouverte si null). */
    private LocalDate dateFin;

    /** Motif de l'immobilisation (ex. Accident, Panne, Immobilisation administrative…). */
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

    /** Clôture l'immobilisation (fin anticipée ou normale). */
    public void terminer() {
        this.statut = IndisponibiliteStatut.TERMINEE;
        if (this.dateFin == null || this.dateFin.isAfter(LocalDate.now())) {
            this.dateFin = LocalDate.now();
        }
    }

    /** Annule l'immobilisation. */
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
     * Validation à la création : une immobilisation ne peut pas être définie
     * sur une date ou une période antérieure à aujourd'hui.
     */
    public void validerPourCreation() {
        validerCoherence();
        if (dateDebut.isBefore(LocalDate.now())) {
            throw new IllegalArgumentException(
                    "L'immobilisation ne peut pas être définie sur une date ou une période antérieure à aujourd'hui.");
        }
    }

    public Long getVehiculeId() {
        return vehicule != null ? vehicule.getId() : null;
    }
}
