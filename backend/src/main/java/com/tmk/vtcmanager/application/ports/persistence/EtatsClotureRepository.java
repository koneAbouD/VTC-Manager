package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.EtatsCloture;

import java.util.Optional;

/** Archive des états figés à chaque clôture mensuelle. */
public interface EtatsClotureRepository {

    EtatsCloture save(EtatsCloture etats);

    /** Photo d'un mois clos, si la clôture a bien archivé ses états. */
    Optional<EtatsCloture> findByPeriode(int annee, int mois);
}
