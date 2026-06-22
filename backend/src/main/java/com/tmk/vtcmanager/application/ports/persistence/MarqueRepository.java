package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.Marque;

import java.util.List;
import java.util.Optional;

public interface MarqueRepository {

    Marque save(Marque marque);

    Optional<Marque> findById(Long id);

    List<Marque> findAll();

    Optional<Marque> findByNom(String nom);

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByNom(String nom);
}
