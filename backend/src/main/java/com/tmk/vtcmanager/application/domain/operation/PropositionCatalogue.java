package com.tmk.vtcmanager.application.domain.operation;

import java.util.List;

/**
 * Éléments que la saisie d'une maintenance propose pour un véhicule.
 *
 * @param modeleId modèle du véhicule, dont les tarifs donnent prix et image ;
 *                 null quand aucun véhicule n'est désigné.
 */
public record PropositionCatalogue(Long modeleId, List<ElementCatalogue> elements) {
}
