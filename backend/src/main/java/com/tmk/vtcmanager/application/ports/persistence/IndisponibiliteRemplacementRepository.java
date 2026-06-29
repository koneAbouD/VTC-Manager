package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteRemplacement;

import java.util.List;

public interface IndisponibiliteRemplacementRepository {

    IndisponibiliteRemplacement save(IndisponibiliteRemplacement remplacement);

    List<IndisponibiliteRemplacement> findByIndisponibiliteId(Long indisponibiliteId);

    void deleteByIndisponibiliteId(Long indisponibiliteId);
}
