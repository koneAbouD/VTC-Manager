package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;

import java.util.List;
import java.util.Optional;

public interface ParametreGeneralRepository {

    List<ParametreGeneral> findAll();

    Optional<ParametreGeneral> findByCle(String cle);

    ParametreGeneral save(ParametreGeneral parametre);
}
