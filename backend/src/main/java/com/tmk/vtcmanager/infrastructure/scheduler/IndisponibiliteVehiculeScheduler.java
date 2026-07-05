package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule.SynchroniserIndisponibilitesVehiculeUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * Tâche planifiée qui, chaque jour, active les indisponibilités véhicule
 * débutant et clôture celles échues, en recalculant le statut des véhicules
 * concernés (IMMOBILISE ↔ recalculé).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class IndisponibiliteVehiculeScheduler {

    private final SynchroniserIndisponibilitesVehiculeUseCase synchroniserIndisponibilitesVehiculeUseCase;

    @Scheduled(cron = "${app.scheduler.indisponibilite-vehicule-cron:0 6 0 * * *}")
    public void synchroniser() {
        int n = synchroniserIndisponibilitesVehiculeUseCase.execute();
        if (n > 0) {
            log.info("Indisponibilités véhicule synchronisées : {} véhicule(s) recalculé(s).", n);
        }
    }
}
