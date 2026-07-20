package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.TypeActivite;

import java.util.List;
import java.util.Optional;

public interface TypeActiviteRepository {

    TypeActivite save(TypeActivite typeActivite);

    List<TypeActivite> findAll();

    List<TypeActivite> findAllActifs();

    Optional<TypeActivite> findById(Long id);

    Optional<TypeActivite> findByNom(String nom);

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByNom(String nom);
}