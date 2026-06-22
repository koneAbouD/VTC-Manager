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
        LocalDate today = LocalDate.now();
        log.info("Génération des lignes de recette pour le {}", today);
        var lignes = genererLignesRecetteUseCase.executer(today);
        log.info("{} ligne(s) de recette générée(s) pour le {}", lignes.size(), today);
    }
}
