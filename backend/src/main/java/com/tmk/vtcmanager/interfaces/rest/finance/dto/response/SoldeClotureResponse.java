package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Solde d'un compte tel qu'archivé à la clôture d'un mois.
 *
 * @param dateDernierComptage jusqu'où ce solde est attesté par un comptage
 *                            réel ; {@code null} si le compte n'avait jamais
 *                            été compté, ou sur une photo antérieure à cet
 *                            archivage
 */
public record SoldeClotureResponse(
        Long compteId,
        String libelleCompte,
        BigDecimal solde,
        LocalDate dateDernierComptage
) {}
