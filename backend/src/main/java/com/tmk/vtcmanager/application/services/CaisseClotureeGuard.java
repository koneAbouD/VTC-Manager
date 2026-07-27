package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.CaisseClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;

/**
 * Verrou d'écriture des caisses comptées.
 *
 * <p>Un comptage n'est opposable que si plus rien ne bouge derrière lui : toute
 * écriture datée dans la journée déjà clôturée — ou avant — est rejetée sur ce
 * compte. La correction passe alors par une écriture du jour, visible, plutôt
 * que par une retouche du passé qui ferait mentir le procès-verbal.
 *
 * <p>Complémentaire du {@link PeriodeClotureeGuard} : celui-ci fige le mois pour
 * toute l'entreprise, celui-là fige la journée pour une caisse.
 */
@RequiredArgsConstructor
public class CaisseClotureeGuard {

    private final ClotureCaisseRepository clotureCaisseRepository;

    public void verifier(Long compteId, LocalDate dateEcriture) {
        if (compteId == null || dateEcriture == null) return;
        clotureCaisseRepository.findDerniereDateCloture(compteId).ifPresent(derniere -> {
            if (!dateEcriture.isAfter(derniere)) {
                throw new CaisseClotureeException(dateEcriture, derniere);
            }
        });
    }
}
