package com.tmk.vtcmanager.interfaces.rest.penalite.dto.response;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

public record LignePenaliteResponse(
        Long id,
        Long vehiculeId,
        String vehiculeImmatriculation,
        Long chauffeurId,
        String chauffeurNomComplet,
        Long penaliteTemplateId,
        String typePenalite,
        String typeSanction,
        BigDecimal montant,
        BigDecimal montantEncaisse,
        BigDecimal montantRestant,
        Integer dureeSanctionSecondes,
        Integer dureeImmobilisationMinutes,
        LocalDateTime dateDebutImmobilisation,
        LocalDateTime dateFinImmobilisation,
        LocalDate dateGeneration,
        LocalDate dateFaute,
        Long ligneRecetteId,
        String statut,
        String commentaire,
        List<EncaissementPenaliteResponse> encaissements
) {}
