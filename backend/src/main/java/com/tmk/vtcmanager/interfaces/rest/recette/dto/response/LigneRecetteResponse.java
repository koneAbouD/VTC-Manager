package com.tmk.vtcmanager.interfaces.rest.recette.dto.response;

import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record LigneRecetteResponse(
        Long id,
        Long vehiculeId,
        String vehiculeImmatriculation,
        Long chauffeurId,
        LocalDate dateRecette,
        BigDecimal montantAttendu,
        BigDecimal montantEncaisse,
        BigDecimal montantRestant,
        StatutLigneRecette statut,
        List<EncaissementResponse> encaissements
) {}
