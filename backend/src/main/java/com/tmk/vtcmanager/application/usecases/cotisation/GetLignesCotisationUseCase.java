package com.tmk.vtcmanager.application.usecases.cotisation;

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

    public LigneCotisation findById(Long id) {
        return ligneCotisationRepository.findById(id)
                .orElseThrow(() -> new LigneCotisationNotFoundException(id));
    }
}
