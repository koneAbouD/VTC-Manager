package com.tmk.vtcmanager.application.domain.penalite;

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
public class EncaissementPenalite {
    private Long id;
    private Long lignePenaliteId;
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

    /**
     * Renseigné à la lecture seulement : faux si la date de ce versement ne
     * peut plus être corrigée — ligne annulée ou arrêtée, versement extourné,
     * période close, caisse comptée. Le client s'en sert pour ne pas proposer
     * un geste voué au refus.
     */
    private Boolean dateModifiable;
    /** Ce qui ferme la correction de date, en français. Null quand elle est ouverte. */
    private String motifDateNonModifiable;
}
