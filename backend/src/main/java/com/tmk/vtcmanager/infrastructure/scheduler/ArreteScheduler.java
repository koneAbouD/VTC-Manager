package com.tmk.vtcmanager.infrastructure.scheduler;

import com.tmk.vtcmanager.application.usecases.arrete.ArreterTousLesChauffeursUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.LocalDate;

/**
 * Restitution mensuelle automatique des cotisations : le 1ᵉʳ de chaque mois,
 * arrête le compte de tous les chauffeurs pour le mois écoulé. Désactivé par
 * défaut (le déclenchement standard reste « à la demande ») ; activer via la
 * propriété {@code arrete.restitution.auto-enabled=true}.
 */
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "arrete.restitution.auto-enabled", havingValue = "true")
public class ArreteScheduler {

    private final ArreterTousLesChauffeursUseCase arreterTousLesChauffeursUseCase;

    @Scheduled(cron = "0 30 6 1 * *")
    public void arreterMoisEcoule() {
        LocalDate finMoisPrecedent = LocalDate.now().withDayOfMonth(1).minusDays(1);
        LocalDate debut = finMoisPrecedent.withDayOfMonth(1);
        log.info("Restitution mensuelle automatique : arrêté des chauffeurs pour {} → {}",
                debut, finMoisPrecedent);
        var arretes = arreterTousLesChauffeursUseCase.executer(
                debut, finMoisPrecedent, LocalDate.now(), null, null);
        log.info("{} arrêté(s) générés automatiquement", arretes.size());
    }
}
