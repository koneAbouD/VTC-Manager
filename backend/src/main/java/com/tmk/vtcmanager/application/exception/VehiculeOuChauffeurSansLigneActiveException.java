package com.tmk.vtcmanager.application.exception;

public class VehiculeOuChauffeurSansLigneActiveException extends RuntimeException {

    public VehiculeOuChauffeurSansLigneActiveException() {
        super("Impossible de créer un encaissement de recette : aucune ligne de recette active (EN_ATTENTE ou PARTIELLEMENT_ENCAISSE) ne correspond au véhicule ou chauffeur pour cette date.");
    }
}
