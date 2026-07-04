package com.tmk.vtcmanager.application.domain.finance;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/** Ligne de balance âgée : total dû par un chauffeur, ventilé par ancienneté. */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreanceChauffeur {

    private Long chauffeurId;
    private String chauffeurNom;
    private String chauffeurPrenom;
    private int nbLignes;
    /** Restant dû sur documents de moins de 8 jours. */
    private BigDecimal du0a7Jours;
    /** Restant dû sur documents de 8 à 30 jours. */
    private BigDecimal du8a30Jours;
    /** Restant dû sur documents de plus de 30 jours. */
    private BigDecimal duPlus30Jours;
    private BigDecimal total;
}
