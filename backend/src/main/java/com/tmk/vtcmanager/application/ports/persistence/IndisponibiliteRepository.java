package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface IndisponibiliteRepository {

    Indisponibilite save(Indisponibilite indisponibilite);

    Optional<Indisponibilite> findById(Long id);

    List<Indisponibilite> findAll();

    List<Indisponibilite> findByChauffeurId(Long chauffeurId);

    List<Indisponibilite> findByStatut(IndisponibiliteStatut statut);

    /**
     * Indique si le chauffeur (titulaire) est en indisponibilité couvrant la date
     * donnée (signal du statut EN_CONGE). Calculé sur les dates, indépendamment de
     * l'exécution du cron de synchronisation.
     */
    boolean isEnCongeAt(Long chauffeurId, LocalDate date);

    /**
     * Indique si le chauffeur est <b>remplaçant actif</b> à la date donnée :
     * il substitue un titulaire indisponible couvrant cette date (signal du
     * statut EN_SERVICE pour le remplaçant). Calculé sur les dates.
     */
    boolean isRemplacantActifAt(Long chauffeurId, LocalDate date);

    void deleteById(Long id);
}
