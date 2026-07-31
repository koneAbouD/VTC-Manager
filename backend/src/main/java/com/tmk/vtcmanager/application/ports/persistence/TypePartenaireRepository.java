package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.partenaire.TypePartenaire;

import java.util.List;
import java.util.Optional;

public interface TypePartenaireRepository {

    TypePartenaire save(TypePartenaire typePartenaire);

    List<TypePartenaire> findAll();

    List<TypePartenaire> findAllActifs();

    Optional<TypePartenaire> findById(Long id);

    Optional<TypePartenaire> findByNom(String nom);

    void deleteById(Long id);

    boolean existsById(Long id);

    boolean existsByNom(String nom);

    /** Vrai si au moins un partenaire porte ce type : il ne se supprime plus. */
    boolean estUtilise(Long id);
}
