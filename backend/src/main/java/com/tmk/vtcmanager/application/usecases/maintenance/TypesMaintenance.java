package com.tmk.vtcmanager.application.usecases.maintenance;

import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;

import java.util.ArrayList;
import java.util.List;

/**
 * Résout les types d'une maintenance saisie. Chaque type doit être une
 * catégorie de la sous-catégorie « Maintenances ». Le client envoie les
 * identifiants des types, type principal en tête ; un client plus ancien
 * n'envoie que le code du type principal ({@code type}), encore accepté.
 *
 * <p>Après résolution, les types portent leur code et leur libellé, le type
 * principal est le premier de la liste et {@code type} reprend son code.
 */
final class TypesMaintenance {

    private static final String SOUS_CATEGORIE_MAINTENANCES = "Maintenances";

    private TypesMaintenance() {}

    static void resoudre(Maintenance maintenance, CategorieOperationRepository repository) {
        List<CategorieOperation> valides = repository.findBySousCategorieLibelle(SOUS_CATEGORIE_MAINTENANCES);
        List<Long> ids = maintenance.idsTypes();

        List<CategorieOperation> resolus = new ArrayList<>();
        for (Long id : ids) {
            resolus.add(valides.stream()
                    .filter(c -> id.equals(c.getId()))
                    .findFirst()
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Le type choisi n'est pas un type de maintenance.")));
        }
        String code = maintenance.getType();
        if (resolus.isEmpty() && code != null && !code.isBlank()) {
            resolus.add(valides.stream()
                    .filter(c -> code.equals(c.getCode()))
                    .findFirst()
                    .orElseThrow(() -> new IllegalArgumentException(
                            "Type de maintenance invalide : '" + code + "'. Types disponibles : "
                                    + valides.stream().map(CategorieOperation::getCode).toList())));
        }

        maintenance.setCategoriesTypes(resolus);
        maintenance.setCategorieType(null);
        maintenance.normaliserTypes();
        if (maintenance.getCategorieType() != null) {
            maintenance.setType(maintenance.getCategorieType().getCode());
        }
    }
}
