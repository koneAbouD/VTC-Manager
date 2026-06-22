package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;

public record ContraventionResponse(
        Long id,
        LocalDate dateInfraction,
        String typeInfraction,
        String lieu,
        String description,
        BigDecimal montant,
        BigDecimal cotisation,
        BigDecimal montantPaye,
        ContraventionStatus statut,
        LocalDate datePaiement,
        ChauffeurResponse chauffeur,
        VehiculeResponse vehicule
) {}