package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.contravention.Contravention;
import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface ContraventionRepository {

    Contravention save(Contravention contravention);

    Optional<Contravention> findById(Long id);

    List<Contravention> findAll();

    /**
     * @param recherche mot-clé libre (immatriculation, nom/prénom du chauffeur,
     *                  numéro de contravention) ; ignoré s'il est vide
     */
    PageResult<Contravention> findPage(Long chauffeurId, Long vehiculeId,
                                       LocalDate dateDebut, LocalDate dateFin,
                                       String recherche, int page, int size);

    List<Contravention> findByChauffeurId(Long chauffeurId);

    List<Contravention> findByVehiculeId(Long vehiculeId);

    List<Contravention> findByStatut(ContraventionStatus statut);

    /** Vrai si une contravention avec ce numéro de relevé existe déjà (anti-doublon import). */
    boolean existsByNumero(String numeroContravention);

    /** Contravention portant ce numéro de relevé (rapprochement quittance) ; vide si absente. */
    Optional<Contravention> findByNumero(String numeroContravention);

    void deleteById(Long id);
}
