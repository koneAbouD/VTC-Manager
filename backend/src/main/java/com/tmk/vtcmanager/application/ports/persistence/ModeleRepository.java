package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.Modele;

import java.util.List;
import java.util.Optional;

public interface ModeleRepository {

    Modele save(Modele modele);

    Optional<Modele> findById(Long id);

    List<Modele> findAll();

    Optional<Modele> findByNom(String nom);

    List<Modele> findByMarqueId(Long marqueId);

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByNom(String nom);
}
