package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;

import java.util.List;
import java.util.Optional;

public interface ContraventionRepository {

    Contravention save(Contravention contravention);

    Optional<Contravention> findById(Long id);

    List<Contravention> findAll();

    List<Contravention> findByChauffeurId(Long chauffeurId);

    List<Contravention> findByVehiculeId(Long vehiculeId);

    List<Contravention> findByStatut(ContraventionStatus statut);

    void deleteById(Long id);
}
