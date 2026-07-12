package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.finance.CompteCourant;

import java.util.List;

/**
 * Lecture des soldes de compte courant : fonds de cotisation restituable face
 * aux créances ouvertes (hors cotisations, comptées dans le fonds), par axe.
 */
public interface CompteCourantRepository {

    List<CompteCourant> getComptesCourantsParChauffeur();

    List<CompteCourant> getComptesCourantsParVehicule();
}
