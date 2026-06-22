package com.tmk.vtcmanager.interfaces.rest.conditionTravail.dto.response;

public record PenaliteTemplateResponse(
        Long id,
        String typePenalite,
        String typeSanction,
        Integer dureeSanctionSecondes,
        Double montant,
        Integer dureeImmobilisationMinutes
) {}
