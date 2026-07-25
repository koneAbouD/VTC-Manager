package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response;

import com.tmk.vtcmanager.application.domain.operation.NatureResultat;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;

public record CategorieOperationResponse(
        Long id,
        String code,
        String libelle,
        TypeOperation typeOperation,
        NatureResultat natureResultat,
        boolean actif,
        // Libellé plat du groupe (sous-catégorie) : pré-remplit la liste
        // déroulante à l'édition côté formulaire générique.
        String sousCategorieLibelle,
        SousCategorieOperationResponse sousCategorie
) {}
