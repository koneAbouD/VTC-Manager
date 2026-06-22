package com.tmk.vtcmanager.application.domain.recette;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;

@Data
@Builder
public class LigneRecetteFiltres {
    private Long vehiculeId;
    private Long chauffeurId;
    private StatutLigneRecette statut;
    private LocalDate dateDebut;
    private LocalDate dateFin;
}
