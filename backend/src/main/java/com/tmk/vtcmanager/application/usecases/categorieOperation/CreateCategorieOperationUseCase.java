package com.tmk.vtcmanager.application.usecases.categorieOperation;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;

@RequiredArgsConstructor
public class CreateCategorieOperationUseCase {

    private final CategorieOperationRepository categorieRepository;

    @Transactional
    public CategorieOperation execute(CategorieOperation categorie) {
        // Le code n'est plus saisi : on le dérive du libellé (majuscules, sans
        // accents) en garantissant l'unicité. Si un code est fourni (compat), on
        // conserve la vérification d'unicité classique.
        if (categorie.getCode() == null || categorie.getCode().isBlank()) {
            categorie.setCode(genererCodeUnique(categorie.getLibelle()));
        } else if (categorieRepository.existsByCode(categorie.getCode())) {
            throw new ResourceAlreadyExistsException(
                    "Une catégorie avec le code '" + categorie.getCode() + "' existe déjà.");
        }
        categorie.setActif(true);
        return categorieRepository.save(categorie);
    }

    /**
     * Génère un code à partir du libellé : sans accents, en MAJUSCULES, les
     * caractères non alphanumériques remplacés par « _ ». En cas de collision,
     * suffixe « _2 », « _3 », … pour respecter l'unicité.
     */
    private String genererCodeUnique(String libelle) {
        String base = Normalizer.normalize(libelle == null ? "" : libelle, Normalizer.Form.NFD)
                .replaceAll("\\p{M}", "")
                .toUpperCase()
                .replaceAll("[^A-Z0-9]+", "_")
                .replaceAll("^_+|_+$", "");
        if (base.isBlank()) {
            base = "CATEGORIE";
        }
        String code = base;
        int suffixe = 2;
        while (categorieRepository.existsByCode(code)) {
            code = base + "_" + suffixe++;
        }
        return code;
    }
}
