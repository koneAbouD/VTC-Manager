package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class AnnulerLigneCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;

    @Transactional
    public LigneCotisation executer(Long id) {
        LigneCotisation ligne = ligneCotisationRepository.findById(id)
                .orElseThrow(() -> new LigneCotisationNotFoundException(id));
        if (ligne.getStatut() != StatutLigneCotisation.ANNULEE) {
            ligne.setStatut(StatutLigneCotisation.ANNULEE);
            return ligneCotisationRepository.save(ligne);
        }
        return ligne;
    }
}
