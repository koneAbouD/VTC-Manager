package com.tmk.vtcmanager.application.ports.persistence;

import java.util.List;

/**
 * Accès ciblé aux assignations de chauffeurs dans les programmes véhicule
 * (table vehicule_programme_chauffeurs), pour les substitutions liées aux
 * indisponibilités.
 */
public interface ProgrammeChauffeurAssignmentPort {

    /** Identifiants des lignes d'assignation où ce chauffeur est affecté. */
    List<Long> findProgrammeChauffeurIdsByChauffeur(Long chauffeurId);

    /** Réaffecte une ligne d'assignation à un autre chauffeur. */
    void reassignChauffeur(Long programmeChauffeurId, Long nouveauChauffeurId);
}
