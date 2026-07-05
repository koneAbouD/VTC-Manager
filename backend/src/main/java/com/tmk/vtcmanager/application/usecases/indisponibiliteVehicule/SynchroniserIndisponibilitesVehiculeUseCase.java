package com.tmk.vtcmanager.application.usecases.indisponibiliteVehicule;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.domain.indisponibiliteVehicule.IndisponibiliteVehicule;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteVehiculeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Synchronise les indisponibilités véhicule avec le calendrier :
 *  - active celles dont la période a commencé (PLANIFIEE → EN_COURS) ;
 *  - clôture celles dont la période est échue (EN_COURS → TERMINEE).
 * Chaque transition republie un {@code VehiculeStatutDirtyEvent} pour que le
 * statut du véhicule (IMMOBILISE ↔ recalculé) reste exact au fil des jours.
 * <p>
 * Idempotent : rejouable sans effet de bord (utilisé par le cron).
 */
@RequiredArgsConstructor
public class SynchroniserIndisponibilitesVehiculeUseCase {

    private final IndisponibiliteVehiculeRepository indisponibiliteVehiculeRepository;
    private final VehiculeStatutEventPublisher vehiculeStatutEventPublisher;

    /** @return nombre d'indisponibilités modifiées. */
    @Transactional
    public int execute() {
        final LocalDate today = LocalDate.now();
        int modifiees = 0;

        // 1) Activation des immobilisations dont la période a commencé.
        final List<IndisponibiliteVehicule> planifiees =
                indisponibiliteVehiculeRepository.findByStatut(IndisponibiliteStatut.PLANIFIEE);
        for (IndisponibiliteVehicule i : planifiees) {
            if (i.getDateDebut() != null && !i.getDateDebut().isAfter(today)
                    && (i.getDateFin() == null || !i.getDateFin().isBefore(today))) {
                i.setStatut(IndisponibiliteStatut.EN_COURS);
                indisponibiliteVehiculeRepository.save(i);
                vehiculeStatutEventPublisher.publishStatutDirty(i.getVehiculeId());
                modifiees++;
            }
        }

        // 2) Clôture des immobilisations échues.
        final List<IndisponibiliteVehicule> enCours =
                indisponibiliteVehiculeRepository.findByStatut(IndisponibiliteStatut.EN_COURS);
        for (IndisponibiliteVehicule i : enCours) {
            if (i.getDateFin() != null && i.getDateFin().isBefore(today)) {
                i.setStatut(IndisponibiliteStatut.TERMINEE);
                indisponibiliteVehiculeRepository.save(i);
                vehiculeStatutEventPublisher.publishStatutDirty(i.getVehiculeId());
                modifiees++;
            }
        }
        return modifiees;
    }
}
