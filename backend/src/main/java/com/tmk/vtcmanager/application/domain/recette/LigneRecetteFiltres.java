package com.tmk.vtcmanager.application.domain.recette;

import lombok.Builder;
import lombok.Data;

import java.time.LocalDate;
import java.util.List;

@Data
@Builder
public class LigneRecetteFiltres {
    private Long vehiculeId;
    private Long chauffeurId;
    private StatutLigneRecette statut;
    /** Plusieurs statuts acceptés à la fois (OU) ; vide ou null = aucun filtre. */
    private List<StatutLigneRecette> statuts;
    private LocalDate dateDebut;
    private LocalDate dateFin;
    /** Mot-clé libre : immatriculation du véhicule ou nom/prénom du chauffeur. */
    private String recherche;
}
