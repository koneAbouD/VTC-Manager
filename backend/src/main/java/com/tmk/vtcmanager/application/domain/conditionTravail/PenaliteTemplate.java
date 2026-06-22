package com.tmk.vtcmanager.application.domain.conditionTravail;

import lombok.Data;

@Data
public class PenaliteTemplate {
    Long id;
    String typePenalite;
    String typeSanction;
    Integer dureeSanctionSecondes;
    Double montant;
    Integer dureeImmobilisationMinutes;
}
