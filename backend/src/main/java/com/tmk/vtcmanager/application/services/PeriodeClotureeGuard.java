package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.exception.PeriodeClotureeException;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;

/**
 * Verrou d'écriture des périodes clôturées : toute création ou annulation
 * d'écriture datée dans (ou avant) la dernière période clôturée est
 * rejetée. C'est ce qui rend les états à date passée (bilan, résultat,
 * export) fiables.
 */
@RequiredArgsConstructor
public class PeriodeClotureeGuard {

    private final CloturePeriodeRepository cloturePeriodeRepository;

    public void verifier(LocalDate dateEcriture) {
        if (dateEcriture == null) return;
        cloturePeriodeRepository.findDerniere().ifPresent(derniere -> {
            if (!dateEcriture.isAfter(derniere.finPeriode())) {
                throw new PeriodeClotureeException(dateEcriture);
            }
        });
    }
}
