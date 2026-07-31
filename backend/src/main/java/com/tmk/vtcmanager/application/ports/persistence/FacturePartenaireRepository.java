package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.partenaire.FacturePartenaire;
import com.tmk.vtcmanager.application.domain.partenaire.LigneDette;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface FacturePartenaireRepository {

    FacturePartenaire save(FacturePartenaire facture);

    Optional<FacturePartenaire> findById(Long id);

    /** Factures d'une période, par date de facture (bornes incluses). */
    List<FacturePartenaire> findByPeriode(LocalDate debut, LocalDate fin);

    /** Factures encore ouvertes, de la plus ancienne échéance à la plus récente. */
    List<FacturePartenaire> findOuvertes(Long partenaireId);

    /** Dettes nées d'une intervention, annulées comprises. */
    List<FacturePartenaire> findByMaintenanceId(Long maintenanceId);

    /**
     * Lignes d'intervention couvertes par chaque dette, indexées par facture.
     * Une facture ne voit que les lignes qui lui reviennent : celles portant son
     * partenaire, plus celles sans prestataire propre quand elle est due au
     * partenaire de l'intervention.
     */
    java.util.Map<Long, List<LigneDette>> lignesParFacture(List<Long> factureIds);

    /**
     * Dette partenaires à une date : reste dû des factures émises jusqu'à cette
     * date, déduction faite des règlements intervenus jusqu'à cette date.
     */
    BigDecimal detteALaDate(LocalDate date);

    /** Charges engagées d'une période, groupées par nature de résultat. */
    java.util.Map<String, BigDecimal> chargesEngageesParNature(LocalDate debut, LocalDate fin);
}
