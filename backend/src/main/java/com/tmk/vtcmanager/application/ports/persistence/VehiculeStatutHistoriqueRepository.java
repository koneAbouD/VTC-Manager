package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatutHistorique;

import java.util.List;
import java.util.Optional;

public interface VehiculeStatutHistoriqueRepository {

    VehiculeStatutHistorique save(VehiculeStatutHistorique historique);

    /** Période en cours (dateFin null) d'un véhicule, s'il en a une. */
    Optional<VehiculeStatutHistorique> findEnCoursByVehiculeId(Long vehiculeId);

    /** Toutes les périodes en cours du parc (une par véhicule au plus). */
    List<VehiculeStatutHistorique> findAllEnCours();

    List<VehiculeStatutHistorique> findByVehiculeId(Long vehiculeId);
}
