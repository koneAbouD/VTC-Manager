package com.tmk.vtcmanager.application.domain.maintenance;

import java.util.List;

/**
 * Compteurs de l'écran des maintenances, que la liste paginée ne peut pas
 * calculer : elle n'a chargé que ses premières pages.
 *
 * @param parType   types ayant au moins une intervention, du plus fréquent au
 *                  moins fréquent ; ignore le filtre de type.
 * @param parStatut tous les statuts, y compris ceux sans intervention ; suit le
 *                  filtre de type, ignore celui de statut.
 * @param enRetard  planifiées dont la date prévue est passée, sur la même base
 *                  que {@code parStatut}.
 */
public record SyntheseMaintenances(
        List<TotalMaintenanceParType> parType,
        List<TotalMaintenanceParStatut> parStatut,
        long enRetard) {
}
