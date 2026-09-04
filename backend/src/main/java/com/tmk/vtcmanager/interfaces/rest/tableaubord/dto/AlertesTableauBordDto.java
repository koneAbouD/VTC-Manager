package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

/**
 * Bloc « qu'est-ce qui menace la suite » : ce qui n'a pas encore coûté, mais
 * coûtera. Reprend les alertes de l'état de parc et y ajoute ce que seule une
 * lecture financière voit — les arrêts qui s'éternisent et les écarts de
 * caisse laissés sans imputation.
 */
public record AlertesTableauBordDto(
        int documentsExpirantSous30Jours,
        /** Véhicules dont une maintenance planifiée est échue ou due sous 7 j
         *  (repris de l'état de parc, en véhicules et non en lignes). */
        int maintenancesDuesSous7Jours,
        int permisExpires,
        int vidangesDues,
        /** Véhicules à l'arrêt depuis plus de 15 jours. */
        int immobilisationsLongues,
        /** Véhicules disponibles faute de chauffeur : le parc est là, il ne roule pas. */
        int vehiculesSansChauffeur
) {}
