package com.tmk.vtcmanager.application.exception;

/**
 * Levée lorsqu'on présente comme un seul versement une recette et une
 * cotisation qui ne sont pas sœurs : un billet se remet pour un véhicule, par
 * un chauffeur, pour une journée.
 */
public class VersementIncoherentException extends RuntimeException {

    public VersementIncoherentException(String message) {
        super(message);
    }
}
