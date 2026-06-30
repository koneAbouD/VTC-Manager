package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;

import java.util.List;
import java.util.Optional;

public interface EncaissementRepository {

    Encaissement save(Encaissement encaissement);

    Optional<Encaissement> findById(Long id);

    List<Encaissement> findByLigneRecetteId(Long ligneRecetteId);

    /** Encaissement rattaché à une opération financière (lien 1-1). */
    Optional<Encaissement> findByOperationFinanciereId(Long operationFinanciereId);

    void deleteById(Long id);
}
