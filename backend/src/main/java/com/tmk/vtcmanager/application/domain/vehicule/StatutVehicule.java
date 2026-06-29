package com.tmk.vtcmanager.application.domain.vehicule;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Métadonnées d'affichage d'un statut de véhicule (table de référence).
 * Le {@code code} correspond à une valeur de {@link VehiculeStatus}.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StatutVehicule {

    private String code;
    private String libelle;
    private String signification;
    private String couleur;
    private Integer ordre;
}
