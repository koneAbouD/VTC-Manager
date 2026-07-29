package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.fournisseur.Fournisseur;

import java.util.List;
import java.util.Optional;

public interface FournisseurRepository {

    Fournisseur save(Fournisseur fournisseur);

    Optional<Fournisseur> findById(Long id);

    List<Fournisseur> findAll(boolean actifsSeulement);

    boolean existsByNom(String nom);
}
