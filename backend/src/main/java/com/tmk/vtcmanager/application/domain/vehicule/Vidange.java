package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Une vidange effectuée sur un véhicule. La ligne porte à la fois l'événement
 * réalisé (date + kilométrage) et, facultativement, la cible de la prochaine
 * vidange (date + kilométrage). La vidange la plus récente d'un véhicule fait
 * office de « dernière vidange » ; sa cible fait office de « prochaine vidange ».
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Vidange {

    private Long id;
    private Long vehiculeId;
    private LocalDate dateVidange;
    private Integer kilometrageVidange;
    private LocalDate dateProchaineVidange;
    private Integer kilometrageProchaineVidange;
    private String commentaire;

    /** Validation métier : dates et kilométrages cohérents. */
    public void valider() {
        if (dateVidange == null) {
            throw new IllegalArgumentException("La date de la vidange est obligatoire.");
        }
        if (kilometrageVidange == null || kilometrageVidange < 0) {
            throw new IllegalArgumentException("Le kilométrage de la vidange doit être positif.");
        }
        if (dateProchaineVidange != null && dateProchaineVidange.isBefore(dateVidange)) {
            throw new IllegalArgumentException(
                    "La date de la prochaine vidange ne peut pas être antérieure à celle de la vidange.");
        }
        if (kilometrageProchaineVidange != null && kilometrageProchaineVidange < kilometrageVidange) {
            throw new IllegalArgumentException(
                    "Le kilométrage de la prochaine vidange ne peut pas être inférieur à celui de la vidange.");
        }
    }
}
