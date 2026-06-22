package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.groupe.GroupeVehicule;

import java.util.List;
import java.util.Optional;

public interface GroupeVehiculeRepository {

    GroupeVehicule save(GroupeVehicule groupe);

    Optional<GroupeVehicule> findById(Long id);

    List<GroupeVehicule> findAll();

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByNom(String nom);
}