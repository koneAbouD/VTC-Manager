package com.tmk.vtcmanager.application.ports.extraction;

import java.util.List;

/**
 * Résultat de l'extraction d'un relevé de contraventions : la plaque du véhicule
 * (en-tête du document) et les lignes d'infraction.
 */
public record ReleveContraventions(
        String plaque,
        List<ContraventionExtraite> contraventions
) {}
