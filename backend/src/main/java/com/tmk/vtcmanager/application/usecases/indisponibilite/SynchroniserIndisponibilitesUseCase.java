package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Synchronise les indisponibilités avec le calendrier :
 *  - active celles dont la période a commencé (PLANIFIEE → EN_COURS) en
 *    appliquant l'impact sur le programme ;
 *  - clôture celles dont la période est échue (EN_COURS → TERMINEE) en
 *    rétablissant le programme.
 *
 * Idempotent : peut être rejoué sans effet de bord (utilisé par le cron).
 */
@RequiredArgsConstructor
public class SynchroniserIndisponibilitesUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;

    /** @return nombre d'indisponibilités modifiées. */
    @Transactional
    public int execute() {
        final LocalDate today = LocalDate.now();
        int modifiees = 0;

        // 1) Activation des indisponibilités dont la période a commencé.
        final List<Indisponibilite> planifiees =
                indisponibiliteRepository.findByStatut(IndisponibiliteStatut.PLANIFIEE);
        for (Indisponibilite i : planifiees) {
            if (i.getDateDebut() != null && !i.getDateDebut().isAfter(today)
                    && (i.getDateFin() == null || !i.getDateFin().isBefore(today))) {
                i.setStatut(IndisponibiliteStatut.EN_COURS);
                indisponibiliteRepository.save(i);
                modifiees++;
            }
        }

        // 2) Clôture des indisponibilités échues.
        final List<Indisponibilite> enCours =
                indisponibiliteRepository.findByStatut(IndisponibiliteStatut.EN_COURS);
        for (Indisponibilite i : enCours) {
            if (i.getDateFin() != null && i.getDateFin().isBefore(today)) {
                i.setStatut(IndisponibiliteStatut.TERMINEE);
                indisponibiliteRepository.save(i);
                modifiees++;
            }
        }
        return modifiees;
    }
}
