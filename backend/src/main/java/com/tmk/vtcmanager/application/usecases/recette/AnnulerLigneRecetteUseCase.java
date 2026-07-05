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
    public LigneRecette executer(Long id, String motif) {
        LigneRecette ligne = ligneRecetteRepository.findById(id)
                .orElseThrow(() -> new LigneRecetteNotFoundException(id));

        if (ligne.getStatut() == StatutLigneRecette.ANNULEE) {
            return ligne;
        }
        if (motif == null || motif.isBlank()) {
            throw new IllegalArgumentException("Le motif d'annulation est obligatoire.");
        }
        // Une ligne déjà encaissée (même partiellement) touche la trésorerie :
        // il faut d'abord annuler les encaissements liés avant de pouvoir annuler
        // la ligne (garantit la cohérence des finances).
        if (ligne.aDesVersements()) {
            throw new IllegalStateException(
                    "Impossible d'annuler une ligne ayant déjà des versements. "
                            + "Annulez d'abord les encaissements liés.");
        }

        ligne.annuler(motif.trim());
        return ligneRecetteRepository.save(ligne);
    }
}
