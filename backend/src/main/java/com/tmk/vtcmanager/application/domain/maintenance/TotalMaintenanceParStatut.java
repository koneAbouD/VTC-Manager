package com.tmk.vtcmanager.application.domain.maintenance;

/**
 * Nombre de maintenances d'un statut sur la sélection demandée.
 */
public record TotalMaintenanceParStatut(MaintenanceStatus statut, long nombre) {
}
