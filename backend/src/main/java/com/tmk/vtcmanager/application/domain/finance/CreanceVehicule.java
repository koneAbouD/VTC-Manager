package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * Ligne de balance âgée agrégée par véhicule : total dû rattaché à un véhicule
 * (recettes, cotisations, pénalités, contraventions ouvertes), tous chauffeurs
 * confondus, ventilé par ancienneté.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreanceVehicule {

    private Long vehiculeId;
    private String immatriculation;
    private String marque;
    private String modele;
    private int nbLignes;
    /** Restant dû sur documents de moins de 8 jours. */
    private BigDecimal du0a7Jours;
    /** Restant dû sur documents de 8 à 30 jours. */
    private BigDecimal du8a30Jours;
    /** Restant dû sur documents de plus de 30 jours. */
    private BigDecimal duPlus30Jours;
    private BigDecimal total;
}
