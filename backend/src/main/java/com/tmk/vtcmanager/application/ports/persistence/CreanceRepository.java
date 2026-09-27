package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.CreanceVehicule;
import com.tmk.vtcmanager.application.domain.finance.FiltreCreances;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/** Projections sur la vue v_creances_chauffeurs (balance des tiers). */
public interface CreanceRepository {

    /** Balance âgée agrégée par chauffeur, triée par total décroissant. */
    default List<CreanceChauffeur> getBalanceAgee() {
        return getBalanceAgee(FiltreCreances.AUCUN);
    }

    /** Même balance, restreinte au mois et au mot-clé de {@code filtre}. */
    List<CreanceChauffeur> getBalanceAgee(FiltreCreances filtre);

    /**
     * Même balance, mais reconstituée telle qu'elle se présentait au soir de
     * {@code date} : documents nés à cette date au plus tard, diminués des seuls
     * règlements intervenus jusque-là, et tranches d'ancienneté comptées depuis
     * ce jour. C'est cette lecture — et non le stock courant — qui doit entrer
     * dans les états d'une période clôturée.
     */
    List<CreanceChauffeur> getBalanceAgeeALaDate(LocalDate date);

    /** Documents ouverts d'un chauffeur, du plus ancien au plus récent. */
    default List<LigneCreance> getLignesCreance(Long chauffeurId) {
        return getLignesCreance(chauffeurId, FiltreCreances.AUCUN);
    }

    List<LigneCreance> getLignesCreance(Long chauffeurId, FiltreCreances filtre);

    /** Balance âgée agrégée par véhicule, triée par total décroissant. */
    default List<CreanceVehicule> getBalanceAgeeParVehicule() {
        return getBalanceAgeeParVehicule(FiltreCreances.AUCUN);
    }

    List<CreanceVehicule> getBalanceAgeeParVehicule(FiltreCreances filtre);

    /** Documents ouverts rattachés à un véhicule, du plus ancien au plus récent. */
    default List<LigneCreance> getLignesCreanceParVehicule(Long vehiculeId) {
        return getLignesCreanceParVehicule(vehiculeId, FiltreCreances.AUCUN);
    }

    List<LigneCreance> getLignesCreanceParVehicule(Long vehiculeId, FiltreCreances filtre);

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
