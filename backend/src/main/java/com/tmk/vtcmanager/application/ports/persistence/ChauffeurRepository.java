package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;

import java.util.List;
import java.util.Optional;

public interface ChauffeurRepository {

    Chauffeur save(Chauffeur chauffeur);

    Optional<Chauffeur> findById(Long id);

    List<Chauffeur> findAll();

    List<Chauffeur> findByStatut(ChauffeurStatus statut);

    void deleteById(Long id);
}
