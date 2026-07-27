package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;

import java.time.LocalDate;
import java.util.List;

public interface ClotureCaisseRepository {

    ClotureCaisse save(ClotureCaisse cloture);

    boolean existsByCompteIdAndDateCloture(Long compteId, LocalDate date);

    List<ClotureCaisse> findByCompteIdOrderByDateDesc(Long compteId);

    /** Date du dernier comptage du compte, s'il y en a eu un. */
    java.util.Optional<LocalDate> findDerniereDateCloture(Long compteId);

    java.util.Optional<ClotureCaisse> findById(Long id);
}
