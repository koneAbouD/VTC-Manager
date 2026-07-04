package com.tmk.vtcmanager.application.usecases.finance;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.exception.PeriodeNonCloturableException;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.YearMonth;

@RequiredArgsConstructor
public class CloturerPeriodeUseCase {

    private final CloturePeriodeRepository cloturePeriodeRepository;

    /**
     * Clôture un mois strictement passé (jamais le mois courant : les
     * opérations du jour, datées d'aujourd'hui, doivent rester possibles).
     * Les clôtures doivent être contiguës : on clôture le mois qui suit la
     * dernière période clôturée — pas de trou dans le verrou.
     */
    @Transactional
    public CloturePeriode executer(int annee, int mois) {
        YearMonth periode = YearMonth.of(annee, mois);
        if (!periode.isBefore(YearMonth.now())) {
            throw new PeriodeNonCloturableException(
                    "Seul un mois strictement passé peut être clôturé");
        }
        if (cloturePeriodeRepository.existsByAnneeAndMois(annee, mois)) {
            throw new PeriodeNonCloturableException(
                    "La période " + mois + "/" + annee + " est déjà clôturée");
        }
        cloturePeriodeRepository.findDerniere().ifPresent(derniere -> {
            YearMonth attendue = YearMonth.of(derniere.getAnnee(), derniere.getMois()).plusMonths(1);
            if (!periode.equals(attendue)) {
                throw new PeriodeNonCloturableException(
                        "La prochaine période à clôturer est " + attendue.getMonthValue()
                                + "/" + attendue.getYear());
            }
        });

        CloturePeriode cloture = CloturePeriode.builder()
                .annee(annee)
                .mois(mois)
                .dateCloture(LocalDateTime.now())
                .build();
        return cloturePeriodeRepository.save(cloture);
    }
}
