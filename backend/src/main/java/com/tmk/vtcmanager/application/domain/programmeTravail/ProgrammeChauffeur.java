package com.tmk.vtcmanager.application.domain.programmeTravail;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProgrammeChauffeur {

    private Long id;
    private Chauffeur chauffeur;
    private Integer ordreAlternance;
    private Integer ordreJourSalaire;
    private LocalDate dateService;

    public Long getChauffeurId() {
        return chauffeur != null ? chauffeur.getId() : null;
    }

    public String getNomComplet() {
        return chauffeur != null ? chauffeur.getFullName() : "";
    }
}
