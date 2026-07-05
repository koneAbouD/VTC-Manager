package com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response;

import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record LigneCotisationResponse(
        Long id,
        Long vehiculeId,
        String vehiculeImmatriculation,
        Long chauffeurId,
        String chauffeurNom,
        LocalDate dateCotisation,
        String nomCotisation,
        BigDecimal montantDu,
        BigDecimal montantEncaisse,
        BigDecimal montantRestant,
        StatutLigneCotisation statut,
        String motifAnnulation,
        List<EncaissementCotisationResponse> encaissements
) {}
