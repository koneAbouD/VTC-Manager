package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.recette.GenererLignesRecetteUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Slf4j
@Component
@RequiredArgsConstructor
public class RecetteScheduler {

    private final GenererLignesRecetteUseCase genererLignesRecetteUseCase;

    @Scheduled(cron = "0 0 6 * * *")
    public void genererLignesRecetteQuotidiennes() {
        // Principe : la génération du jour J concerne la veille (J-1).
        LocalDate hier = LocalDate.now().minusDays(1);
        log.info("Génération des lignes de recette pour le {}", hier);
        var lignes = genererLignesRecetteUseCase.executer(hier);
        log.info("{} ligne(s) de recette générée(s) pour le {}", lignes.size(), hier);
    }
}
