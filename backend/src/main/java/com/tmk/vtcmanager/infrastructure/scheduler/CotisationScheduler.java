package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.cotisation.GenererLignesCotisationUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

@Slf4j
@Component
@RequiredArgsConstructor
public class CotisationScheduler {

    private final GenererLignesCotisationUseCase genererLignesCotisationUseCase;

    @Scheduled(cron = "0 5 6 * * *")
    public void genererLignesCotisationQuotidiennes() {
        LocalDate today = LocalDate.now();
        log.info("Génération des lignes de cotisation pour le {}", today);
        var lignes = genererLignesCotisationUseCase.executer(today);
        log.info("{} ligne(s) de cotisation générée(s) pour le {}", lignes.size(), today);
    }
}
