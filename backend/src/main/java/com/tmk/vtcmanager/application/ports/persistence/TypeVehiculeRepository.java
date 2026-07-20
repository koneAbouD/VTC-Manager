package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.TypeVehicule;

import java.util.List;
import java.util.Optional;

public interface TypeVehiculeRepository {

    TypeVehicule save(TypeVehicule typeVehicule);

    Optional<TypeVehicule> findById(Long id);

    List<TypeVehicule> findAll();

    List<TypeVehicule> findAllActifs();

    Optional<TypeVehicule> findByNom(String nom);

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByNom(String nom);
}
