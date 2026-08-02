package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.CreanceVehicule;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Projections sur la vue v_creances_chauffeurs (balance des tiers). */
public interface CreanceRepository {

    /** Balance âgée agrégée par chauffeur, triée par total décroissant. */
    List<CreanceChauffeur> getBalanceAgee();

    /**
     * Même balance, mais reconstituée telle qu'elle se présentait au soir de
     * {@code date} : documents nés à cette date au plus tard, diminués des seuls
     * règlements intervenus jusque-là, et tranches d'ancienneté comptées depuis
     * ce jour. C'est cette lecture — et non le stock courant — qui doit entrer
     * dans les états d'une période clôturée.
     */
    List<CreanceChauffeur> getBalanceAgeeALaDate(LocalDate date);

    /** Documents ouverts d'un chauffeur, du plus ancien au plus récent. */
    List<LigneCreance> getLignesCreance(Long chauffeurId);

    /** Balance âgée agrégée par véhicule, triée par total décroissant. */
    List<CreanceVehicule> getBalanceAgeeParVehicule();

    /** Documents ouverts rattachés à un véhicule, du plus ancien au plus récent. */
    List<LigneCreance> getLignesCreanceParVehicule(Long vehiculeId);

    /**
     * Montant encaissé auprès des chauffeurs pour des contraventions non
     * encore reversées à l'État (dette envers l'État).
     */
    BigDecimal getMontantAReverserEtat();

    /**
     * Même dette, arrêtée au soir de {@code date} : sommes déjà encaissées à
     * cette date et pas encore reversées ce jour-là.
     */
    BigDecimal getMontantAReverserEtatALaDate(LocalDate date);
}
