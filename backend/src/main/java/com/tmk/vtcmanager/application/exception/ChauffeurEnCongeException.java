package com.tmk.vtcmanager.application.exception;

import lombok.Getter;

/**
 * Levée lorsqu'on tente d'ajouter à un programme un chauffeur actuellement en
 * congé. Ne concerne qu'un <b>nouvel</b> ajout : un titulaire déjà présent qui
 * part en congé reste valide (modèle overlay).
 */
@Getter
public class ChauffeurEnCongeException extends RuntimeException {

    private final Long chauffeurId;
    private final String chauffeurNom;

    public ChauffeurEnCongeException(Long chauffeurId, String chauffeurNom) {
        super(String.format(
                "Le chauffeur '%s' est en congé et ne peut pas être affecté à un programme.",
                chauffeurNom));
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
    }
}
