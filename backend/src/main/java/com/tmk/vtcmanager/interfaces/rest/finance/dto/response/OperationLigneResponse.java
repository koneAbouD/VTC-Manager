package com.tmk.vtcmanager.interfaces.rest.finance.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;

public record OperationLigneResponse(
        Long id,
        String type,
        String description,
        String categorieCode,
        String categorieLibelle,
        String chauffeurNom,
        String vehiculeLabel,
        /** Montant signé : négatif sur une extourne, qui rend l'argent. */
        BigDecimal montant,
        LocalDate date,
        /** Cette écriture est une contre-passation. */
        boolean estUneExtourne,
        /** Cette écriture a été contre-passée : elle reste au journal, barrée. */
        boolean estExtournee
) {}
