package com.tmk.vtcmanager.application.exception;

import lombok.Getter;

/**
 * Levée lorsqu'on tente d'affecter à un programme un chauffeur dont le permis de
 * conduire est expiré.
 */
@Getter
public class ChauffeurPermisExpireException extends RuntimeException {

    private final Long chauffeurId;
    private final String chauffeurNom;

    public ChauffeurPermisExpireException(Long chauffeurId, String chauffeurNom) {
        super(String.format(
                "Le chauffeur '%s' a un permis de conduire expiré : affectation impossible. "
                        + "Mettez à jour son permis avant de l'affecter.",
                chauffeurNom));
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
    }
}
