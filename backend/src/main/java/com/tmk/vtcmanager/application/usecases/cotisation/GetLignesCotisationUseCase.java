package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

@RequiredArgsConstructor
public class GetLignesCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;

    public List<LigneCotisation> findByCriteres(LigneCotisationFiltres filtres) {
        return ligneCotisationRepository.findByCriteres(filtres);
    }

    public PageResult<LigneCotisation> findPageByCriteres(LigneCotisationFiltres filtres, int page, int size) {
        return ligneCotisationRepository.findPageByCriteres(filtres, page, size);
    }

    public LigneCotisation findById(Long id) {
        return ligneCotisationRepository.findById(id)
                .orElseThrow(() -> new LigneCotisationNotFoundException(id));
    }
}
