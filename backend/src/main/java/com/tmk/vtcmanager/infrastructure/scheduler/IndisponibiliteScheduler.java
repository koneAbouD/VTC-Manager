package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.indisponibilite.SynchroniserIndisponibilitesUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Tâche planifiée qui, chaque jour, active les indisponibilités débutant et
 * clôture celles échues, en réalignant les programmes véhicule en conséquence.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class IndisponibiliteScheduler {

    private final SynchroniserIndisponibilitesUseCase synchroniserIndisponibilitesUseCase;

    @Scheduled(cron = "${app.scheduler.indisponibilite-cron:0 5 0 * * *}")
    public void synchroniser() {
        int n = synchroniserIndisponibilitesUseCase.execute();
        if (n > 0) {
            log.info("Indisponibilités synchronisées : {} programme(s) réaligné(s).", n);
        }
    }
}
