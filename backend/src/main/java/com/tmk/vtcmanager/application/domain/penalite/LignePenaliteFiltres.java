package com.tmk.vtcmanager.application.domain.penalite;

import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;

@Data
@Builder
public class LignePenaliteFiltres {
    private Long vehiculeId;
    private Long chauffeurId;
    private TypeSanction typeSanction;
    private StatutLignePenalite statut;
    private LocalDate dateDebut;
    private LocalDate dateFin;
}
