package com.tmk.vtcmanager.application.usecases.operationFinanciere;

import com.tmk.vtcmanager.application.domain.operation.SoldePeriode;
import com.tmk.vtcmanager.application.ports.persistence.OperationFinanciereRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;

/**
 * Calcule le solde / revenus / dépenses de la carte d'accueil sur une période.
 * La granularité (jour / semaine / mois) est résolue côté client en une plage
 * [debut, fin] ; ici on ne connaît que la plage. Opérations annulées exclues.
 */
@RequiredArgsConstructor
public class CalculerSoldeOperationsFinancieresUseCase {

    private final OperationFinanciereRepository repository;

    public SoldePeriode execute(LocalDate debut, LocalDate fin) {
        return repository.calculerSolde(debut, fin);
    }
}
