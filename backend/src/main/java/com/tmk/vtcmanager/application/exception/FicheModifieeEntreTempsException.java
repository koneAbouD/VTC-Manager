package com.tmk.vtcmanager.application.exception;

/**
 * La fiche a changé depuis que l'utilisateur l'a ouverte : un autre
 * gestionnaire l'a modifiée, ou l'application elle-même (statut recalculé,
 * affectation). Enregistrer la saisie écraserait ces changements sans que
 * personne ne le voie ; on la refuse et l'on fait relire la fiche.
 *
 * <p>Le risque grandit avec le cache des applications, qui peut ouvrir une
 * fiche telle qu'elle était lors de la dernière connexion.
 */
public class FicheModifieeEntreTempsException extends RuntimeException {

    public FicheModifieeEntreTempsException(String fiche) {
        super("Ce " + fiche + " a été modifié depuis l'ouverture de la fiche. "
                + "Rouvrez-la pour repartir de la version à jour, puis refaites "
                + "votre modification.");
    }

    /** Refuse la saisie si elle part d'une autre version que la fiche actuelle. */
    public static void verifier(String fiche, Long versionSaisie, Long versionActuelle) {
        if (versionSaisie != null && !versionSaisie.equals(versionActuelle)) {
            throw new FicheModifieeEntreTempsException(fiche);
        }
    }
}
