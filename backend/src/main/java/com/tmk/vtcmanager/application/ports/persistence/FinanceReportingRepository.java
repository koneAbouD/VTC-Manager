package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.AmortissementVehicule;
import com.tmk.vtcmanager.application.domain.finance.MargeVehicule;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/** Agrégats de reporting (compte de résultat, marges, immobilisations). */
public interface FinanceReportingRepository {

    /**
     * Base caisse : montants des opérations terminées de la période,
     * groupés par nature de résultat (HORS_RESULTAT exclu).
     * Clés : PRODUIT_EXPLOITATION, CHARGE_VARIABLE, CHARGE_FIXE.
     */
    Map<String, BigDecimal> totauxCaisseParNature(LocalDate debut, LocalDate fin);

    /**
     * Même agrégat que {@link #totauxCaisseParNature}, mais sans les règlements
     * de factures fournisseurs : leur charge est déjà portée par la facture, la
     * lecture en base engagement ne doit pas la compter une seconde fois.
     */
    Map<String, BigDecimal> totauxCaisseHorsFactureParNature(LocalDate debut, LocalDate fin);

    /**
     * Base engagement : produits dus de la période par date métier
     * (recettes attendues + cotisations + pénalités AMENDE émises),
     * lignes annulées exclues.
     */
    BigDecimal produitsEngagement(LocalDate debut, LocalDate fin);

    /** Dotation linéaire des véhicules amortissables sur la période. */
    BigDecimal dotationAmortissements(LocalDate debut, LocalDate fin);

    /** Σ valeur nette comptable des véhicules à la date donnée. */
    BigDecimal immobilisationsNettes(LocalDate date);

    /**
     * Plan d'amortissement d'un véhicule à une date — la part de
     * {@link #immobilisationsNettes} qui lui revient, servie au détail.
     * Vide si le véhicule n'existe pas.
     */
    Optional<AmortissementVehicule> amortissementVehicule(Long vehiculeId, LocalDate date);

    /** Marge sur coûts variables par véhicule (base caisse), triée décroissante. */
    List<MargeVehicule> margesParVehicule(LocalDate debut, LocalDate fin);
}
