package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.finance.CompteCourant;
import com.tmk.vtcmanager.application.ports.persistence.CompteCourantRepository;
import lombok.RequiredArgsConstructor;

import java.util.List;

/** Lecture des soldes de compte courant, par chauffeur ou par véhicule. */
@RequiredArgsConstructor
public class GetCompteCourantUseCase {

    private final CompteCourantRepository compteCourantRepository;

    public List<CompteCourant> lister(PerimetreArrete perimetre) {
        return lister(perimetre, null);
    }

    /** @param recherche chauffeur ou immatriculation (null ou vide = tous) */
    public List<CompteCourant> lister(PerimetreArrete perimetre, String recherche) {
        return perimetre == PerimetreArrete.VEHICULE
                ? compteCourantRepository.getComptesCourantsParVehicule(recherche)
                : compteCourantRepository.getComptesCourantsParChauffeur(recherche);
    }
}
