package com.tmk.vtcmanager.application.ports.event;

/**
 * Port de sortie permettant aux use cases d'émettre une demande de recalcul du
 * statut d'un chauffeur sans connaître le mécanisme d'événements sous-jacent.
 */
public interface ChauffeurStatutEventPublisher {

    /** Publie le fait qu'un signal du chauffeur a changé et que son statut doit être recalculé. */
    void publishStatutDirty(Long chauffeurId);
}
