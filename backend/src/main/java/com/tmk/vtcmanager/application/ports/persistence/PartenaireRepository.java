package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;

import java.util.List;
import java.util.Optional;

public interface PartenaireRepository {

    Partenaire save(Partenaire partenaire);

    Optional<Partenaire> findById(Long id);

    List<Partenaire> findAll(boolean actifsSeulement);

    boolean existsByNom(String nom);
}
