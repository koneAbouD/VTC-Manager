package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetLignesRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;

    public List<LigneRecette> findByCriteres(LigneRecetteFiltres filtres) {
        return ligneRecetteRepository.findByCriteres(filtres);
    }

    public PageResult<LigneRecette> findPageByCriteres(LigneRecetteFiltres filtres, int page, int size) {
        return ligneRecetteRepository.findPageByCriteres(filtres, page, size);
    }

    public LigneRecette findById(Long id) {
        return ligneRecetteRepository.findById(id)
                .orElseThrow(() -> new LigneRecetteNotFoundException(id));
    }
}
