package com.tmk.vtcmanager.application.exception;

public class VehiculeOuChauffeurSansLigneCotisationActiveException extends RuntimeException {

    public VehiculeOuChauffeurSansLigneCotisationActiveException() {
        super("Impossible de créer un encaissement de cotisation : aucune ligne de cotisation active ne correspond au véhicule ou chauffeur pour cette date.");
    }
}
