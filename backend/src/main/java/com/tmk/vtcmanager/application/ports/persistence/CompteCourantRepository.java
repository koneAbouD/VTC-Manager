package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.CompteCourant;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * Lecture des soldes de compte courant : fonds de cotisation restituable face
 * aux créances ouvertes (hors cotisations, comptées dans le fonds), par axe.
 */
public interface CompteCourantRepository {

    default List<CompteCourant> getComptesCourantsParChauffeur() {
        return getComptesCourantsParChauffeur(null);
    }

    default List<CompteCourant> getComptesCourantsParVehicule() {
        return getComptesCourantsParVehicule(null);
    }

    /**
     * Soldes par chauffeur, restreints aux chauffeurs dont le nom répond au
     * mot-clé ou qui ont roulé (cotisation ou créance) un véhicule dont
     * l'immatriculation y répond. Le compte reste entier : seule la liste des
     * tiers est filtrée, jamais leurs lignes.
     *
     * @param recherche mot-clé (null ou vide = aucun filtre)
     */
    List<CompteCourant> getComptesCourantsParChauffeur(String recherche);

    /** Pendant véhicule de {@link #getComptesCourantsParChauffeur(String)}. */
    List<CompteCourant> getComptesCourantsParVehicule(String recherche);

    /**
     * Total des dépôts de cotisation encore détenus à une date : encaissements
     * intervenus jusque-là, diminués de ceux qu'un arrêté avait déjà restitués
     * à cette date.
     *
     * <p>C'est un montant <b>brut</b>, sans compensation avec les créances des
     * chauffeurs. La dette de restitution et la créance de recette sont deux
     * postes distincts du bilan : les compenser ferait disparaître les deux.
     */
    BigDecimal fondsCotisationsALaDate(LocalDate date);
}
