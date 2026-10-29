package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.response;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.SyntheseMaintenances;

import java.math.BigDecimal;
import java.util.List;

/**
 * Compteurs de l'écran des maintenances : tuiles par type, pastilles par statut
 * et nombre en retard. La liste paginée ne peut pas les calculer, elle n'a
 * chargé que ses premières pages.
 */
public record SyntheseMaintenancesResponse(
        List<TypeResponse> parType,
        List<StatutResponse> parStatut,
        long enRetard) {

    public record TypeResponse(
            Long categorieTypeId,
            String code,
            String libelle,
            long nombre,
            BigDecimal coutRealise) {
    }

    public record StatutResponse(MaintenanceStatus statut, long nombre) {
    }

    public static SyntheseMaintenancesResponse from(SyntheseMaintenances synthese) {
        return new SyntheseMaintenancesResponse(
                synthese.parType().stream()
                        .map(t -> new TypeResponse(t.categorieTypeId(), t.code(), t.libelle(),
                                t.nombre(), t.coutRealise()))
                        .toList(),
                synthese.parStatut().stream()
                        .map(s -> new StatutResponse(s.statut(), s.nombre()))
                        .toList(),
                synthese.enRetard());
    }
}
