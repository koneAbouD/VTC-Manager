package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;

import java.util.List;
import java.util.Optional;

public interface CloturePeriodeRepository {

    CloturePeriode save(CloturePeriode cloture);

    boolean existsByAnneeAndMois(int annee, int mois);

    /** Période clôturée la plus récente (borne du verrou d'écriture). */
    Optional<CloturePeriode> findDerniere();

    List<CloturePeriode> findAllOrderByPeriodeDesc();
}
