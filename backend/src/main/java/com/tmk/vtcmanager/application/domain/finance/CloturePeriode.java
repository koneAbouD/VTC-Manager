package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.YearMonth;

/** Période comptable mensuelle figée : plus aucune écriture datée dedans. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CloturePeriode {

    private Long id;
    private int annee;
    private int mois;
    private LocalDateTime dateCloture;

    /** Dernier jour de la période clôturée. */
    public LocalDate finPeriode() {
        return YearMonth.of(annee, mois).atEndOfMonth();
    }
}
