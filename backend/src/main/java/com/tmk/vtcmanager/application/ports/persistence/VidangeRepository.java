package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.Vidange;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface VidangeRepository {

    Vidange save(Vidange vidange);

    /** Historique complet d'un véhicule, de la plus récente à la plus ancienne. */
    List<Vidange> findByVehiculeId(Long vehiculeId);

    /** Dernière vidange enregistrée d'un véhicule, s'il en a une. */
    Optional<Vidange> findDerniereByVehiculeId(Long vehiculeId);

    /**
     * Dernière vidange de chaque véhicule dont la prochaine vidange est planifiée
     * dans l'intervalle [debut, fin]. Sert au rappel automatique de vidange.
     */
    List<Vidange> findDernieresAvecProchaineEntre(LocalDate debut, LocalDate fin);

    /** Dernière vidange de chaque véhicule (une par véhicule). Pour l'état de parc. */
    List<Vidange> findDernieresParVehicule();
}
