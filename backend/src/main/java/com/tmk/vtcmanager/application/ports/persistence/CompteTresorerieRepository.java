package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;

import java.util.List;
import java.util.Optional;

public interface CompteTresorerieRepository {

    CompteTresorerie save(CompteTresorerie compte);

    Optional<CompteTresorerie> findById(Long id);

    Optional<CompteTresorerie> findByCode(String code);

    List<CompteTresorerie> findAll();

    List<CompteTresorerie> findByActifTrue();

    Optional<CompteTresorerie> findParDefautByType(TypeCompteTresorerie type);

    long countActifsByType(TypeCompteTresorerie type);

    boolean existsByCode(String code);

    /**
     * Comptes avec solde courant = solde_initial + somme des opérations
     * terminées (REVENU en +, DEPENSE en −) + transferts nets, statut
     * ANNULEE exclu.
     */
    List<CompteAvecSolde> findAllAvecSoldes(boolean actifsSeulement);

    /** Solde courant d'un seul compte (même formule). */
    Optional<CompteAvecSolde> findAvecSoldeById(Long id);
}
