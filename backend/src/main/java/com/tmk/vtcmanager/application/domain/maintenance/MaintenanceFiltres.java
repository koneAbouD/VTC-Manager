package com.tmk.vtcmanager.application.domain.maintenance;

import java.time.LocalDate;
import java.util.List;

/**
 * Sélection de maintenances demandée par l'écran de liste : la même sert la
 * page et les cumuls, pour que « la période affichée » recouvre partout la même
 * chose.
 *
 * @param recherche        mot-clé libre (type, immatriculation, prestataire) ;
 *                         ignoré s'il est vide.
 * @param categorieTypeIds types de maintenance retenus ; vide = tous les types.
 * @param enRetard         vrai pour ne garder que les planifiées dont la date
 *                         prévue est passée.
 */
public record MaintenanceFiltres(
        LocalDate dateDebut,
        LocalDate dateFin,
        MaintenanceStatus statut,
        Long vehiculeId,
        String recherche,
        List<Long> categorieTypeIds,
        boolean enRetard) {

    public MaintenanceFiltres {
        categorieTypeIds = categorieTypeIds == null ? List.of() : List.copyOf(categorieTypeIds);
    }

    /**
     * Les compteurs de statut servent justement à choisir un statut (ou le
     * retard) : filtrés dessus, toutes les autres pastilles tomberaient à zéro.
     */
    public MaintenanceFiltres sansStatut() {
        return new MaintenanceFiltres(dateDebut, dateFin, null, vehiculeId, recherche,
                categorieTypeIds, false);
    }

    /**
     * Même raisonnement pour les tuiles de types : cocher la vidange ne doit pas
     * faire disparaître les autres types de l'écran.
     */
    public MaintenanceFiltres sansType() {
        return new MaintenanceFiltres(dateDebut, dateFin, statut, vehiculeId, recherche,
                List.of(), enRetard);
    }

    public MaintenanceFiltres seulementEnRetard() {
        return new MaintenanceFiltres(dateDebut, dateFin, null, vehiculeId, recherche,
                categorieTypeIds, true);
    }
}
