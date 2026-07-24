package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;

import java.util.List;
import java.util.Optional;

public interface BaliseRepository {

    Balise save(Balise balise);

    List<Balise> findAll();

    List<Balise> findAllActifs();

    Optional<Balise> findById(Long id);

    Optional<Balise> findByIdentifiant(String identifiant);

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByIdentifiant(String identifiant);
}
