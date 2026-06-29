package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;

import java.util.List;
import java.util.Optional;

public interface IndisponibiliteRepository {

    Indisponibilite save(Indisponibilite indisponibilite);

    Optional<Indisponibilite> findById(Long id);

    List<Indisponibilite> findAll();

    List<Indisponibilite> findByChauffeurId(Long chauffeurId);

    List<Indisponibilite> findByStatut(IndisponibiliteStatut statut);

    void deleteById(Long id);
}
