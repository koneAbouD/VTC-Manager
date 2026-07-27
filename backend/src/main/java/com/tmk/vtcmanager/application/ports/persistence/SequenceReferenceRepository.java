package com.tmk.vtcmanager.application.ports.persistence;

/**
 * Compteur de pièces par journal et par exercice, garanti sans trou ni doublon
 * même sous saisies concurrentes.
 */
public interface SequenceReferenceRepository {

    /**
     * Réserve et retourne le numéro suivant du journal pour l'exercice donné.
     * L'appel est atomique : deux saisies simultanées obtiennent deux numéros
     * distincts et consécutifs.
     */
    long suivant(String journal, int exercice);
}
