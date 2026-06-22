package com.tmk.vtcmanager.application.domain.groupe;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class GestionnaireGroupe {

    private Long id;
    private String userId;
    private String username;
    private LocalDate dateDebut;
    private LocalDate dateFin;
}