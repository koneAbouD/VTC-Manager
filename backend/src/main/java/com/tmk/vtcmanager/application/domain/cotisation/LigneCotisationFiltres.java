package com.tmk.vtcmanager.application.domain.cotisation;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;

@Data
@Builder
public class LigneCotisationFiltres {
    private Long vehiculeId;
    private Long chauffeurId;
    private StatutLigneCotisation statut;
    private LocalDate dateDebut;
    private LocalDate dateFin;
}
