package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.coherence.ConflitChauffeurJour;

import java.time.LocalDate;
import java.util.List;

/** Contrôles de cohérence passés sur les créances générées. */
public interface CoherenceGenerationRepository {

    /**
     * Chauffeurs portant des créances vivantes sur plus d'un véhicule, jour par
     * jour, entre {@code debut} et {@code fin} (bornes incluses) — recettes et
     * cotisations confondues. Les lignes annulées sont ignorées : elles
     * n'engagent plus personne.
     *
     * <p>Une plage plutôt qu'une date : le contrôle d'après-génération ne
     * regarde qu'un jour, mais l'écran Recettes affiche un mois et doit pouvoir
     * signaler tout ce qu'il couvre.
     */
    List<ConflitChauffeurJour> chauffeursSurPlusieursVehicules(LocalDate debut, LocalDate fin);
}
