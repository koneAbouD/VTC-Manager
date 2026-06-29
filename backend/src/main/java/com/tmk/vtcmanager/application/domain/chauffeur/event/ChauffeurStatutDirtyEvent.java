package com.tmk.vtcmanager.application.domain.chauffeur.event;

/**
 * Signale qu'un signal influençant le statut d'un chauffeur a changé
 * (création/modification/clôture d'indisponibilité…) et que son statut doit être
 * recalculé. Émis par les use cases producteurs et consommé par un listener
 * unique qui délègue au recalcul.
 */
public record ChauffeurStatutDirtyEvent(Long chauffeurId) {
}
