package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;

import java.util.List;
import java.util.Optional;

public interface ContraventionRepository {

    Contravention save(Contravention contravention);

    Optional<Contravention> findById(Long id);

    List<Contravention> findAll();

    PageResult<Contravention> findPage(Long chauffeurId, Long vehiculeId, int page, int size);

    List<Contravention> findByChauffeurId(Long chauffeurId);

    List<Contravention> findByVehiculeId(Long vehiculeId);

    List<Contravention> findByStatut(ContraventionStatus statut);

    /** Vrai si une contravention avec ce numéro de relevé existe déjà (anti-doublon import). */
    boolean existsByNumero(String numeroContravention);

    void deleteById(Long id);
}
