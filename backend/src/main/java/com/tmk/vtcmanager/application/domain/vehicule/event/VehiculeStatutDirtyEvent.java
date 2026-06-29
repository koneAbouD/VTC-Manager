package com.tmk.vtcmanager.application.domain.vehicule.event;

/**
 * Signale qu'un signal influençant le statut d'un véhicule a changé
 * (affectation chauffeur, maintenance, immobilisation pénalité…) et que son
 * statut doit être recalculé. Émis par les use cases producteurs et consommé
 * par un listener unique qui délègue au recalcul.
 */
public record VehiculeStatutDirtyEvent(Long vehiculeId) {
}
