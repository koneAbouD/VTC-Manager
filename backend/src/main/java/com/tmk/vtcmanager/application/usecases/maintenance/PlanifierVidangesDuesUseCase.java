package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.vehicule.Vidange;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.application.ports.persistence.VidangeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Planifie automatiquement une maintenance de type « Vidange » lorsqu'on arrive
 * à {@value #JOURS_AVANT} jours (ou moins) de la date prévue de la prochaine
 * vidange d'un véhicule.
 *
 * <p>Pour chaque véhicule, seule la vidange courante (la plus récente) est
 * considérée. La maintenance est planifiée à la date prévue de la vidange. Le
 * traitement est idempotent : si une maintenance « Vidange » (non annulée) existe
 * déjà pour ce véhicule à cette date, elle n'est pas recréée — la tâche peut donc
 * s'exécuter chaque jour sans générer de doublon.</p>
 */
@RequiredArgsConstructor
public class PlanifierVidangesDuesUseCase {

    /** Code de catégorie de maintenance (cf. sous-catégorie « Maintenances »). */
    public static final String TYPE_VIDANGE = "VIDANGE";

    /** Fenêtre d'anticipation : on planifie à 7 jours de la date prévue. */
    private static final int JOURS_AVANT = 7;

    private final VidangeRepository vidangeRepository;
    private final MaintenanceRepository maintenanceRepository;
    private final ScheduleMaintenanceUseCase scheduleMaintenanceUseCase;

    /** @return le nombre de maintenances de vidange effectivement créées. */
    @Transactional
    public int execute() {
        LocalDate aujourdhui = LocalDate.now();
        LocalDate limite = aujourdhui.plusDays(JOURS_AVANT);

        List<Vidange> dues =
                vidangeRepository.findDernieresAvecProchaineEntre(aujourdhui, limite);

        int crees = 0;
        for (Vidange vidange : dues) {
            Long vehiculeId = vidange.getVehiculeId();
            LocalDate datePrevue = vidange.getDateProchaineVidange();
            if (vehiculeId == null || datePrevue == null) continue;
            if (maintenanceVidangeDejaPlanifiee(vehiculeId, datePrevue)) continue;

            Maintenance maintenance = Maintenance.builder()
                    .type(TYPE_VIDANGE)
                    .datePrevue(datePrevue)
                    .kilometrageProchaine(vidange.getKilometrageProchaineVidange())
                    .description("Vidange planifiée automatiquement (rappel à "
                            + JOURS_AVANT + " jours de la date prévue).")
                    .statut(MaintenanceStatus.PLANIFIEE)
                    .build();

            scheduleMaintenanceUseCase.execute(vehiculeId, maintenance);
            crees++;
        }
        return crees;
    }

    /**
     * Vrai s'il existe déjà, pour ce véhicule à cette date, une maintenance de
     * type « Vidange » non annulée (garantit l'idempotence de la tâche).
     */
    private boolean maintenanceVidangeDejaPlanifiee(Long vehiculeId, LocalDate datePrevue) {
        return maintenanceRepository
                .findByFiltres(datePrevue, datePrevue, null, vehiculeId).stream()
                .anyMatch(m -> TYPE_VIDANGE.equalsIgnoreCase(m.getType())
                        && m.getStatut() != MaintenanceStatus.ANNULEE);
    }
}
