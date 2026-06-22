package com.tmk.vtcmanager.application.usecases.recette;

import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.LigneRecetteNotFoundException;
import com.tmk.vtcmanager.application.exception.LigneRecetteDejaSoldeeException;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

@RequiredArgsConstructor
public class ConfirmerVersementUseCase {

    private final LigneRecetteRepository ligneRecetteRepository;

    @Transactional
    public LigneRecette executer(Long id) {
        LigneRecette ligne = ligneRecetteRepository.findById(id)
                .orElseThrow(() -> new LigneRecetteNotFoundException(id));

        if (!ligne.estActive()) {
            throw new LigneRecetteDejaSoldeeException(id);
        }

        ligne.setStatut(StatutLigneRecette.ENCAISSE);
        return ligneRecetteRepository.save(ligne);
    }
}
