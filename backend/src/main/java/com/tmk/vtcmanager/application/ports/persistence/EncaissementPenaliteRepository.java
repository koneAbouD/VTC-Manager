package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;

import java.util.List;
import java.util.Optional;

public interface EncaissementPenaliteRepository {

    EncaissementPenalite save(EncaissementPenalite encaissement);

    Optional<EncaissementPenalite> findById(Long id);

    List<EncaissementPenalite> findByLignePenaliteId(Long lignePenaliteId);
}
