package com.tmk.vtcmanager.application.domain.jourFerie;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/** Un jour férié daté (Côte d'Ivoire). L'année est dérivée de la date. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class JourFerie {

    private Long id;
    private LocalDate date;
    private String libelle;
    private TypeJourFerie type;
    private Integer annee;
    private SourceJourFerie source;

    public void validate() {
        if (date == null) {
            throw new IllegalArgumentException("La date du jour férié est obligatoire.");
        }
        if (libelle == null || libelle.isBlank()) {
            throw new IllegalArgumentException("Le libellé du jour férié est obligatoire.");
        }
    }

    /** Aligne l'année et les valeurs par défaut avant persistance. */
    public void normalize() {
        if (date != null) {
            annee = date.getYear();
        }
        if (type == null) {
            type = TypeJourFerie.AUTRE;
        }
        if (source == null) {
            source = SourceJourFerie.MANUEL;
        }
        if (libelle != null) {
            libelle = libelle.trim();
        }
    }
}
