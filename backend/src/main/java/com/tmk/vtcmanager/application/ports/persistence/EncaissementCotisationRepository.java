package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;

import java.util.List;
import java.util.Optional;

public interface EncaissementCotisationRepository {

    EncaissementCotisation save(EncaissementCotisation encaissement);

    Optional<EncaissementCotisation> findById(Long id);

    List<EncaissementCotisation> findByLigneCotisationId(Long ligneCotisationId);

    /** Encaissement rattaché à une opération financière (lien 1-1). */
    Optional<EncaissementCotisation> findByOperationFinanciereId(Long operationFinanciereId);

    void deleteById(Long id);
}
