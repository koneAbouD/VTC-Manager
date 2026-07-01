package com.tmk.vtcmanager.application.usecases.penalite;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenaliteFiltres;
import com.tmk.vtcmanager.application.exception.LignePenaliteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetLignesPenaliteUseCase {

    private final LignePenaliteRepository lignePenaliteRepository;

    public List<LignePenalite> findByCriteres(LignePenaliteFiltres filtres) {
        return lignePenaliteRepository.findByCriteres(filtres);
    }

    public PageResult<LignePenalite> findPageByCriteres(LignePenaliteFiltres filtres, int page, int size) {
        return lignePenaliteRepository.findPageByCriteres(filtres, page, size);
    }

    public LignePenalite findById(Long id) {
        return lignePenaliteRepository.findById(id)
                .orElseThrow(() -> new LignePenaliteNotFoundException(id));
    }
}
