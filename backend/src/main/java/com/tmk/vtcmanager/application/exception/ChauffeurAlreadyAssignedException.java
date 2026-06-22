package com.tmk.vtcmanager.application.exception;

import lombok.Getter;

@Getter
public class ChauffeurAlreadyAssignedException extends RuntimeException {

    private final Long chauffeurId;
    private final String chauffeurNom;
    private final Long vehiculeActuelId;
    private final String vehiculeActuelImmatriculation;

    public ChauffeurAlreadyAssignedException(
            Long chauffeurId,
            String chauffeurNom,
            Long vehiculeActuelId,
            String vehiculeActuelImmatriculation) {
        super(String.format(
                "Le chauffeur '%s' est déjà affecté au véhicule '%s'. Confirmez le transfert pour continuer.",
                chauffeurNom, vehiculeActuelImmatriculation));
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
        this.vehiculeActuelId = vehiculeActuelId;
        this.vehiculeActuelImmatriculation = vehiculeActuelImmatriculation;
    }
}
