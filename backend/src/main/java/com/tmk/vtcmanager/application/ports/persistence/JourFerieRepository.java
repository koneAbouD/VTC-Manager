package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface JourFerieRepository {

    JourFerie save(JourFerie jourFerie);

    Optional<JourFerie> findById(Long id);

    /** Tous les jours fériés d'une année, par date croissante. */
    List<JourFerie> findByAnnee(int annee);

    /** Vrai si une date est un jour férié enregistré. Utilisé par la génération. */
    boolean existsByDate(LocalDate date);

    void deleteById(Long id);
}
