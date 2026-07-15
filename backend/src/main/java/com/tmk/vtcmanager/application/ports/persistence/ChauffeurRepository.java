package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;

import java.util.List;
import java.util.Optional;

public interface ChauffeurRepository {

    Chauffeur save(Chauffeur chauffeur);

    Optional<Chauffeur> findById(Long id);

    /** Recherche par identifiant d'utilisateur Keycloak (résolution du chauffeur courant). */
    Optional<Chauffeur> findByKeycloakUserId(String keycloakUserId);

    /** Recherche par numéro de téléphone normalisé (enrôlement / OTP). */
    Optional<Chauffeur> findByTelephone(String telephone);

    List<Chauffeur> findAll();

    PageResult<Chauffeur> findPage(ChauffeurStatus statut, int page, int size);

    List<Chauffeur> findByStatut(ChauffeurStatus statut);

    /** Indique si un chauffeur est actuellement affecté à ce véhicule. */
    boolean existsByVehiculeId(Long vehiculeId);

    void deleteById(Long id);
}
