package com.tmk.vtcmanager.interfaces.rest.reaffectation.dto;

import com.tmk.vtcmanager.application.domain.reaffectation.ApercuReaffectation;

import java.math.BigDecimal;
import java.util.List;

/**
 * Ce que l'écran de réaffectation reçoit à l'ouverture, en un aller-retour.
 *
 * <p>Les impacts sont des faits, pas des phrases : le nom du chauffeur choisi et
 * le format des montants ne sont connus que du client, qui compose la ligne
 * lui-même. Ce qu'il ne pouvait pas savoir, en revanche, c'est s'il existe
 * réellement une pénalité à emmener — il l'annonçait auparavant dans tous les cas.
 */
public record ApercuReaffectationResponse(List<CandidatReaffectationResponse> candidats,
                                          ImpactsResponse impacts) {

    public record CandidatReaffectationResponse(Long chauffeurId, String nom, boolean auProgramme,
                                                boolean actuel, boolean eligible, String motif) {}

    public record ImpactsResponse(BigDecimal montantCreance,
                                  int encaissementsRattaches,
                                  BigDecimal montantEncaisse,
                                  int penalitesQuiSuivent,
                                  BigDecimal montantPenalites) {}

    public static ApercuReaffectationResponse de(ApercuReaffectation apercu) {
        return new ApercuReaffectationResponse(
                apercu.candidats().stream()
                        .map(c -> new CandidatReaffectationResponse(c.chauffeurId(), c.nom(),
                                c.auProgramme(), c.actuel(), c.eligible(), c.motif()))
                        .toList(),
                new ImpactsResponse(
                        apercu.impacts().montantCreance(),
                        apercu.impacts().encaissementsRattaches(),
                        apercu.impacts().montantEncaisse(),
                        apercu.impacts().penalitesQuiSuivent(),
                        apercu.impacts().montantPenalites()));
    }
}
