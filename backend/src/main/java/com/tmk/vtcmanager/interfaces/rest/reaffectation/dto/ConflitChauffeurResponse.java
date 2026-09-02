package com.tmk.vtcmanager.interfaces.rest.reaffectation.dto;

import com.tmk.vtcmanager.application.domain.coherence.ConflitChauffeurJour;

import java.time.LocalDate;
import java.util.List;

/** Un chauffeur portant des créances sur plusieurs véhicules le même jour. */
public record ConflitChauffeurResponse(LocalDate date, Long chauffeurId, String chauffeurNom,
                                       List<String> immatriculations) {

    public static ConflitChauffeurResponse de(ConflitChauffeurJour conflit) {
        return new ConflitChauffeurResponse(conflit.date(), conflit.chauffeurId(),
                conflit.chauffeurNom(), conflit.immatriculations());
    }
}
