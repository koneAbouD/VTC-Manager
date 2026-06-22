package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import lombok.RequiredArgsConstructor;

@RequiredArgsConstructor
public class GetCategorieOperationBySousCategorieUseCase {

    private final CategorieOperationRepository categorieRepository;
    private final SousCategorieOperationRepository sousCategorieRepository;

    public CategorieOperation execute(Long sousCategorieId, String sousCategorieCode,
                                      boolean includeSousCategorie) {
        if (sousCategorieId == null && (sousCategorieCode == null || sousCategorieCode.isBlank())) {
            throw new IllegalArgumentException(
                    "Au moins un critère est requis : sousCategorieId ou sousCategorieCode.");
        }

        SousCategorieOperation sous = resoudreSousCategorie(sousCategorieId, sousCategorieCode);

        CategorieOperation categorie = categorieRepository.findById(sous.getCategorieId())
                .orElseThrow(() -> ResourceNotFoundException.of("Catégorie opération", sous.getCategorieId()));

        if (includeSousCategorie) {
            categorie.setSousCategorie(sous);
        }
        return categorie;
    }

    private SousCategorieOperation resoudreSousCategorie(Long id, String code) {
        if (id != null) {
            return sousCategorieRepository.findById(id)
                    .orElseThrow(() -> ResourceNotFoundException.of("Sous-catégorie opération", id));
        }
        return sousCategorieRepository.findByCode(code)
                .orElseThrow(() -> new ResourceNotFoundException(
                        "Sous-catégorie opération introuvable pour le code : " + code));
    }
}
