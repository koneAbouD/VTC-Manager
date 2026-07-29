package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.fournisseur.FactureFournisseur;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface FactureFournisseurRepository {

    FactureFournisseur save(FactureFournisseur facture);

    Optional<FactureFournisseur> findById(Long id);

    /** Factures d'une période, par date de facture (bornes incluses). */
    List<FactureFournisseur> findByPeriode(LocalDate debut, LocalDate fin);

    /** Factures encore ouvertes, de la plus ancienne échéance à la plus récente. */
    List<FactureFournisseur> findOuvertes(Long fournisseurId);

    /**
     * Dette fournisseurs à une date : reste dû des factures émises jusqu'à cette
     * date, déduction faite des règlements intervenus jusqu'à cette date.
     */
    BigDecimal detteALaDate(LocalDate date);

    /** Charges engagées d'une période, groupées par nature de résultat. */
    java.util.Map<String, BigDecimal> chargesEngageesParNature(LocalDate debut, LocalDate fin);
}
