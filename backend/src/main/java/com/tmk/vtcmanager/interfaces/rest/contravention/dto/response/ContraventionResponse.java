package com.tmk.vtcmanager.interfaces.rest.contravention.dto.response;

import com.tmk.vtcmanager.application.domain.contravention.ContraventionStatus;
import com.tmk.vtcmanager.application.domain.contravention.StatutRattachement;
import com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response.ChauffeurResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

public record ContraventionResponse(
        Long id,
        LocalDate dateInfraction,
        String typeInfraction,
        String lieu,
        String description,
        BigDecimal montant,
        BigDecimal cotisation,
        BigDecimal montantPaye,
        ContraventionStatus statut,
        LocalDate datePaiement,
        ChauffeurResponse chauffeur,
        VehiculeResponse vehicule,
        String numeroContravention,
        LocalTime heureInfraction,
        Integer vitesseRelevee,
        String codeInfraction,
        String documentSourcePath,
        StatutRattachement statutRattachement,
        /** Jour du reversement à l'État ; null tant que la somme est détenue. */
        LocalDate dateReversement,
        /** Renseignés dès lors que la contravention a été annulée. */
        LocalDateTime annuleLe,
        String motifAnnulation,
        /**
         * Faux si un arrêté — période comptable close, caisse comptée — interdit
         * désormais de restaurer cet élément annulé. Le client masque alors
         * l'action « Restaurer », qui n'aboutirait pas.
         */
        Boolean restaurable
) {}