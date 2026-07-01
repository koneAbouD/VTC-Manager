package com.tmk.vtcmanager.application.domain.operation;

import java.time.LocalDate;

public record OperationFinanciereFiltres(
        TypeOperation typeOperation,
        LocalDate debut,
        LocalDate fin,
        StatutOperation statut,
        String recherche,
        String categorieCode,
        Long vehiculeId,
        Long chauffeurId,
        String sousCategorieLibelle
) {}
