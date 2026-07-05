package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface IndisponibiliteVehiculeRepository {

    IndisponibiliteVehicule save(IndisponibiliteVehicule indisponibilite);

    Optional<IndisponibiliteVehicule> findById(Long id);

    List<IndisponibiliteVehicule> findAll();

    PageResult<IndisponibiliteVehicule> findPage(Long vehiculeId, int page, int size);

    List<IndisponibiliteVehicule> findByVehiculeId(Long vehiculeId);

    List<IndisponibiliteVehicule> findByStatut(IndisponibiliteStatut statut);

    /**
     * Indique si le véhicule est immobilisé par une indisponibilité couvrant la
     * date donnée (signal du statut IMMOBILISE et du blocage recette/cotisation/
     * pénalité). Calculé sur les dates (statuts PLANIFIEE/EN_COURS), indépendamment
     * de l'exécution du cron de synchronisation.
     */
    boolean isImmobiliseAt(Long vehiculeId, LocalDate date);

    void deleteById(Long id);
}
