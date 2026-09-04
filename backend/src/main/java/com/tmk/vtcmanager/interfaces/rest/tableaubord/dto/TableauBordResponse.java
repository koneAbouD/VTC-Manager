package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

/**
 * Tableau de bord de supervision : une page qui répond à quatre questions,
 * dans cet ordre — est-ce que je gagne de l'argent (résultat), est-ce que
 * l'argent rentre (cash), est-ce que mon actif produit (flotte), qu'est-ce qui
 * menace la suite (alertes).
 * <p>
 * Chaque bloc est servi par les états déjà publiés (compte de résultat, balance
 * âgée, marges par véhicule, état de parc) : le tableau de bord ne recalcule
 * rien de son côté, il compose — deux écrans ne peuvent donc pas se contredire.
 */
public record TableauBordResponse(
        PeriodeDto periode,
        SanteFinanciereDto finance,
        CashCreancesDto cash,
        PerformanceFlotteDto flotte,
        AlertesTableauBordDto alertes
) {}
