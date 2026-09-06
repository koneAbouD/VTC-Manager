package com.tmk.vtcmanager.interfaces.rest.maintenance.dto.request;

import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.ReglementMaintenance;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.DetailMaintenanceRequest;
import jakarta.validation.Valid;

import java.math.BigDecimal;
import java.time.LocalDate;

public record MaintenanceRequest(
        String type,
        LocalDate datePrevue,
        LocalDate dateEffectuee,
        Integer dureeHeures,
        String description,
        Integer kilometrageAuMoment,
        Integer kilometrageProchaine,
        BigDecimal cout,
        /** Partenaire ayant réalisé l'intervention (facultatif). */
        Long partenaireId,
        MaintenanceStatus statut,
        Long vehiculeId,
        Long categorieTypeId,
        @Valid DetailMaintenanceRequest detailMaintenance,
        /**
         * Vrai si l'intervention déjà réalisée — date prévue passée, donc
         * terminée dès sa création — reste due : dette partenaire au lieu d'un
         * paiement. Sans objet pour une intervention à venir.
         */
        Boolean aCredit,
        /** Échéance de cette dette ; à défaut, due à réception. */
        LocalDate dateEcheance
) {
    /**
     * Règlement appliqué quand la création termine l'intervention d'office
     * (date prévue passée). Sans précision du client, réglée comptant : c'est
     * le cas courant du rattrapage d'une intervention déjà payée.
     */
    public ReglementMaintenance reglement() {
        return Boolean.TRUE.equals(aCredit)
                ? ReglementMaintenance.aCredit(dateEcheance)
                : ReglementMaintenance.comptant(null);
    }
}
