package com.tmk.vtcmanager.application.domain.notification;

/**
 * Application mobile ayant enregistré l'appareil. Un même téléphone peut porter
 * les deux : celui d'un gestionnaire qui conduit aussi, par exemple. Les deux
 * enregistrements sont alors distincts et reçoivent des notifications
 * différentes.
 */
public enum ApplicationCliente {
    /** Application de gestion (mobile/). */
    MANAGER,
    /** Espace chauffeur en self-service (mobile-chauffeur/). */
    CHAUFFEUR
}
