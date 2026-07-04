package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

/**
 * Période passée par un véhicule dans un statut ({@code dateFin} null = période
 * en cours). Une ligne est ouverte à chaque transition effective de statut ;
 * la précédente est close au même instant.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class VehiculeStatutHistorique {

    private Long id;
    private Long vehiculeId;
    private VehiculeStatus statut;
    private VehiculeStatutMotif motif;
    private LocalDateTime dateDebut;
    private LocalDateTime dateFin;

    public boolean estEnCours() {
        return dateFin == null;
    }

    /** Clôt la période à l'instant donné. */
    public void clore(LocalDateTime instant) {
        this.dateFin = instant;
    }

    /** Nombre de jours entiers passés dans le statut (à maintenant si en cours). */
    public long joursDansStatut() {
        LocalDateTime fin = dateFin != null ? dateFin : LocalDateTime.now();
        return ChronoUnit.DAYS.between(dateDebut, fin);
    }
}
