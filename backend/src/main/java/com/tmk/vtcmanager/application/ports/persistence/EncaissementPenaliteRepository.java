package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;

import java.util.List;
import java.util.Optional;

public interface EncaissementPenaliteRepository {

    EncaissementPenalite save(EncaissementPenalite encaissement);

    Optional<EncaissementPenalite> findById(Long id);

    List<EncaissementPenalite> findByLignePenaliteId(Long lignePenaliteId);

    /** Encaissement rattaché à une opération financière (lien 1-1). */
    Optional<EncaissementPenalite> findByOperationFinanciereId(Long operationFinanciereId);

    void deleteById(Long id);
}
