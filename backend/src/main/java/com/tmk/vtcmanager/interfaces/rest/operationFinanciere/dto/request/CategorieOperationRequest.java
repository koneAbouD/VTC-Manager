package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request;

import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CategorieOperationRequest(
        // Le code n'est plus saisi : généré côté backend à partir du libellé
        // (mis en majuscules, unicité garantie). Facultatif ici pour compat.
        String code,
        @NotBlank String libelle,
        // Groupe / famille comptable choisi dans la liste : le backend crée ou
        // met à jour la sous-catégorie 1-1 liée à cette catégorie.
        String sousCategorieLibelle,
        @NotNull TypeOperation typeOperation,
        @NotNull NatureResultat natureResultat,
        boolean actif
) {}
