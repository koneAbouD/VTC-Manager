package com.tmk.vtcmanager.interfaces.rest.tableaubord.dto;

import java.math.BigDecimal;
import java.util.List;

/**
 * Bloc « est-ce que mon actif produit » : le parc est le capital de
 * l'entreprise, chaque véhicule doit couvrir son propre coût d'usure.
 * <p>
 * Deux indicateurs y font le lien entre exploitation et résultat :
 * {@code revenuParVehiculeActif}, qui ramène les produits au nombre de
 * véhicules mobilisables, et {@code manqueAGagnerImmobilisation}, qui valorise
 * les jours d'arrêt au produit journalier moyen d'un véhicule — le coût, en
 * francs, de ce qui n'a pas roulé.
 */
public record PerformanceFlotteDto(
        int parcActif,
        int enService,
        int disponibles,
        int enMaintenance,
        int immobilises,
        int horsParc,
        BigDecimal tauxDisponibilite,
        BigDecimal tauxUtilisation,

        /** Produits de la période / parc actif. */
        BigDecimal revenuParVehiculeActif,
        /** Produit journalier moyen d'un véhicule actif. */
        BigDecimal revenuJournalierMoyen,

        /** Jours d'arrêt cumulés sur la période (immobilisations véhicule). */
        long joursImmobilisation,
        /** Jours d'arrêt / (parc actif × jours de période), en %. */
        BigDecimal tauxImmobilisation,
        /** Jours d'arrêt valorisés au revenu journalier moyen. */
        BigDecimal manqueAGagnerImmobilisation,

        /** Moyenne des marges nettes des véhicules mouvementés sur la période. */
        BigDecimal margeNetteMoyenne,
        /** Véhicules dont la marge nette est négative : ils coûtent plus qu'ils ne rapportent. */
        int nbVehiculesDeficitaires,
        int nbVehiculesEvalues,

        /** Trois meilleures et trois pires marges nettes de la période. */
        List<VehiculePerformanceDto> meilleurs,
        List<VehiculePerformanceDto> moinsBons
) {}
