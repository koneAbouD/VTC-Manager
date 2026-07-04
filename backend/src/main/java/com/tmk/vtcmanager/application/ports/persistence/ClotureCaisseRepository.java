package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;

import java.time.LocalDate;
import java.util.List;

public interface ClotureCaisseRepository {

    ClotureCaisse save(ClotureCaisse cloture);

    boolean existsByCompteIdAndDateCloture(Long compteId, LocalDate date);

    List<ClotureCaisse> findByCompteIdOrderByDateDesc(Long compteId);
}
