package com.tmk.vtcmanager.application.domain.maintenance;

import java.math.BigDecimal;

/**
 * Cumul des maintenances d'un type sur la sélection demandée.
 *
 * @param nombre      interventions de ce type, tous statuts confondus.
 * @param coutRealise somme des coûts des seules interventions terminées : une
 *                    planifiée n'a encore rien coûté, une annulée ne coûtera rien.
 */
public record TotalMaintenanceParType(
        Long categorieTypeId,
        String code,
        String libelle,
        long nombre,
        BigDecimal coutRealise) {

    public TotalMaintenanceParType {
        // SUM sur des lignes sans coût renvoie NULL en SQL.
        coutRealise = coutRealise == null ? BigDecimal.ZERO : coutRealise;
    }
}
