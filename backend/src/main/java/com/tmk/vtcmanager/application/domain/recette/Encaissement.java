package com.tmk.vtcmanager.application.domain.recette;

import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Encaissement {

    private Long id;
    private Long ligneRecetteId;
    private Long operationFinanciereId;
    private BigDecimal montant;
    private ModePaiement modeEncaissement;
    private LocalDate dateEncaissement;
    private String reference;
    private String commentaire;

    /** Annulé (jamais supprimé) : ignoré des recalculs et des agrégats. */
    private LocalDateTime annuleLe;
    private String annulePar;
    private String motifAnnulation;
}
