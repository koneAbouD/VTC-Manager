package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.maintenance.PlanifierVidangesDuesUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Tâche planifiée qui, chaque jour, crée automatiquement une maintenance de type
 * « Vidange » pour les véhicules dont la prochaine vidange arrive à 7 jours (ou
 * moins). Idempotent : pas de doublon si la maintenance existe déjà.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class VidangeReminderScheduler {

    private final PlanifierVidangesDuesUseCase planifierVidangesDuesUseCase;

    @Scheduled(cron = "${app.scheduler.vidange-reminder-cron:0 30 8 * * *}")
    public void planifierVidanges() {
        int n = planifierVidangesDuesUseCase.execute();
        if (n > 0) {
            log.info("Vidanges planifiées automatiquement : {} maintenance(s) créée(s).", n);
        }
    }
}
