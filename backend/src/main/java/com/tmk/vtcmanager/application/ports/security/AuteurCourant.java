package com.tmk.vtcmanager.application.ports.security;

/**
 * Qui agit. Les écritures financières archivent leur auteur automatiquement
 * (audit JPA) ; ce port sert aux cas où l'application doit le nommer
 * elle-même — l'auteur d'une annulation, d'un comptage de caisse, d'une
 * clôture.
 */
public interface AuteurCourant {

    /** Jamais nul : « system » hors requête authentifiée (batch, scheduler). */
    String nom();
}
