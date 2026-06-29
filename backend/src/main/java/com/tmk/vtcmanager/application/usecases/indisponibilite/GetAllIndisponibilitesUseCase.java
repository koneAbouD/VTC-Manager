package com.tmk.vtcmanager.application.usecases.indisponibilite;

import com.tmk.vtcmanager.application.domain.indisponibilite.Indisponibilite;
import com.tmk.vtcmanager.application.ports.persistence.IndisponibiliteRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetAllIndisponibilitesUseCase {

    private final IndisponibiliteRepository indisponibiliteRepository;

    public List<Indisponibilite> execute(Long chauffeurId) {
        if (chauffeurId != null) return indisponibiliteRepository.findByChauffeurId(chauffeurId);
        return indisponibiliteRepository.findAll();
    }
}
