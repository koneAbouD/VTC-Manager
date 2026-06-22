package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.usecases.maintenance.GetUpcomingMaintenancesUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * Tâche planifiée qui inspecte chaque jour les maintenances à venir
 * et émet des journaux de rappel. Une intégration notifications/email
 * peut être ajoutée ici plus tard.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MaintenanceReminderScheduler {

    private static final int JOURS_AVANT = 7;

    private final GetUpcomingMaintenancesUseCase getUpcomingMaintenancesUseCase;

    @Scheduled(cron = "${app.scheduler.maintenance-reminder-cron:0 0 8 * * *}")
    public void notifyUpcomingMaintenances() {
        List<Maintenance> upcoming = getUpcomingMaintenancesUseCase.execute(JOURS_AVANT);
        if (upcoming.isEmpty()) {
            log.info("Aucune maintenance planifiée dans les {} prochains jours", JOURS_AVANT);
            return;
        }
        log.info("{} maintenance(s) à venir dans les {} prochains jours :", upcoming.size(), JOURS_AVANT);
        upcoming.forEach(m -> log.info(" - Maintenance #{} type={} véhicule={} prévue le {}",
                m.getId(),
                m.getType(),
                m.getVehicule() != null ? m.getVehicule().getImmatriculation() : "?",
                m.getDatePrevue()));
    }
}
