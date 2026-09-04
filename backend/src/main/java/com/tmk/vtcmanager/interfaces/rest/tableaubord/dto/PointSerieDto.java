package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;

/**
 * Point de la série mensuelle glissante. Lu en base caisse directement dans
 * l'agrégat des opérations : une courbe de tendance n'a pas besoin de la
 * cascade complète, et douze cascades coûteraient douze fois trop cher.
 * {@code resultat} est donc un EBE — avant amortissements et provisions.
 */
public record PointSerieDto(
        int annee,
        int mois,
        /** « sept. », pour l'axe. */
        String label,
        BigDecimal produits,
        BigDecimal charges,
        BigDecimal resultat
) {}
