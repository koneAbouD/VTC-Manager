package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.CreanceChauffeur;
import com.tmk.vtcmanager.application.domain.finance.LigneCreance;

import java.math.BigDecimal;
import java.util.List;

/** Projections sur la vue v_creances_chauffeurs (balance des tiers). */
public interface CreanceRepository {

    /** Balance âgée agrégée par chauffeur, triée par total décroissant. */
    List<CreanceChauffeur> getBalanceAgee();

    /** Documents ouverts d'un chauffeur, du plus ancien au plus récent. */
    List<LigneCreance> getLignesCreance(Long chauffeurId);

    /**
     * Montant encaissé auprès des chauffeurs pour des contraventions non
     * encore reversées à l'État (dette envers l'État).
     */
    BigDecimal getMontantAReverserEtat();
}
