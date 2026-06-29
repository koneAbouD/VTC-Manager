package com.tmk.vtcmanager.application.ports.event;

/**
 * Port de sortie permettant aux use cases d'émettre une demande de recalcul du
 * statut d'un véhicule sans connaître le mécanisme d'événements sous-jacent.
 */
public interface VehiculeStatutEventPublisher {

    /** Publie le fait qu'un signal du véhicule a changé et que son statut doit être recalculé. */
    void publishStatutDirty(Long vehiculeId);
}
