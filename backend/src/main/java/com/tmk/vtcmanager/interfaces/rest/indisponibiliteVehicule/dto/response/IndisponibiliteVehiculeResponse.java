package com.tmk.vtcmanager.interfaces.rest.indisponibiliteVehicule.dto.response;

import com.tmk.vtcmanager.application.domain.indisponibilite.IndisponibiliteStatut;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.time.LocalDate;

public record IndisponibiliteVehiculeResponse(
        Long id,
        VehiculeResponse vehicule,
        LocalDate dateDebut,
        LocalDate dateFin,
        String motif,
        String commentaire,
        IndisponibiliteStatut statut
) {}
