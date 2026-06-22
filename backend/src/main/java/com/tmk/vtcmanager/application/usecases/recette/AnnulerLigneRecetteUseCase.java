package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class AnnulerLigneRecetteUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;

    @Transactional
    public LigneRecette executer(Long id) {
        LigneRecette ligne = ligneRecetteRepository.findById(id)
                .orElseThrow(() -> new LigneRecetteNotFoundException(id));

        if (ligne.getStatut() == StatutLigneRecette.ANNULEE) {
            return ligne;
        }

        ligne.setStatut(StatutLigneRecette.ANNULEE);
        return ligneRecetteRepository.save(ligne);
    }
}
