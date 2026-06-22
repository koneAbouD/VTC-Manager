package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.penalite.GenererLignesPenaliteUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Slf4j
@Component
@RequiredArgsConstructor
public class PenaliteScheduler {

    private final GenererLignesPenaliteUseCase genererLignesPenaliteUseCase;

    @Scheduled(cron = "0 0 2 * * *")
    public void genererPenalitesRecettesNonVersees() {
        LocalDate hier = LocalDate.now().minusDays(1);
        log.info("Génération des pénalités RECETTE_NON_VERSEE pour le {}", hier);
        var lignes = genererLignesPenaliteUseCase.executerPourRecettesNonVersees(hier);
        log.info("{} ligne(s) de pénalité générée(s) pour le {}", lignes.size(), hier);
    }
}
