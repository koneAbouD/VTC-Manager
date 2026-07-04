package com.tmk.vtcmanager.interfaces.rest.finance;

import com.tmk.vtcmanager.application.domain.finance.GroupByRapport;
import com.tmk.vtcmanager.application.domain.finance.RapportFinancier;
import com.tmk.vtcmanager.application.usecases.finance.GetRapportFinancierUseCase;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.BreakdownItemResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.OperationLigneResponse;
import com.tmk.vtcmanager.interfaces.rest.finance.dto.response.RapportFinancierResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * Rapport financier mensuel consommé par l'écran Finances du mobile.
 * Endpoint historiquement appelé sur {@code /api/rapport-financier} (hors du
 * préfixe {@code /api/finances} des autres états).
 */
@RestController
@RequestMapping("/api/rapport-financier")
@RequiredArgsConstructor
public class RapportFinancierController {

    private final GetRapportFinancierUseCase getRapportFinancierUseCase;

    @GetMapping
    public RapportFinancierResponse getRapport(
            @RequestParam int annee,
            @RequestParam int mois,
            @RequestParam(defaultValue = "CHAUFFEUR") GroupByRapport groupBy) {
        return toResponse(getRapportFinancierUseCase.executer(annee, mois, groupBy));
    }

    private RapportFinancierResponse toResponse(RapportFinancier r) {
        return new RapportFinancierResponse(
                r.getTotalRevenus(),
                r.getTotalDepenses(),
                r.getVariationRevenusPct(),
                r.getVariationDepensesPct(),
                r.getGroupBy(),
                toBreakdown(r.getBreakdownRevenus()),
                toBreakdown(r.getBreakdownDepenses()),
                toOperations(r.getListeOperations()));
    }

    private List<BreakdownItemResponse> toBreakdown(List<RapportFinancier.LigneRepartition> lignes) {
        return lignes.stream()
                .map(l -> new BreakdownItemResponse(l.getLabel(), l.getMontant(), l.getPourcentage()))
                .toList();
    }

    private List<OperationLigneResponse> toOperations(List<RapportFinancier.LigneOperation> lignes) {
        return lignes.stream()
                .map(l -> new OperationLigneResponse(l.getId(), l.getType(), l.getDescription(),
                        l.getChauffeurNom(), l.getVehiculeLabel(), l.getMontant(), l.getDate()))
                .toList();
    }
}
