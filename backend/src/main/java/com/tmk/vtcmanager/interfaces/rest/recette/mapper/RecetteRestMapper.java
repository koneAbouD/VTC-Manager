package com.tmk.vtcmanager.interfaces.rest.recette.mapper;

import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.request.EncaissementRequest;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.EncaissementResponse;
import com.tmk.vtcmanager.interfaces.rest.recette.dto.response.LigneRecetteResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.math.BigDecimal;
import java.util.List;

@Mapper(componentModel = "spring")
public interface RecetteRestMapper {

    @Mapping(target = "id",                  ignore = true)
    @Mapping(target = "ligneRecetteId",      ignore = true)
    @Mapping(target = "operationFinanciereId", ignore = true)
    Encaissement toDomain(EncaissementRequest request);

    EncaissementResponse toResponse(Encaissement encaissement);

    List<EncaissementResponse> toEncaissementResponseList(List<Encaissement> encaissements);

    @Mapping(target = "montantRestant", expression = "java(computeMontantRestant(ligne))")
    @Mapping(target = "encaissements", source = "encaissements")
    LigneRecetteResponse toResponse(LigneRecette ligne);

    List<LigneRecetteResponse> toResponseList(List<LigneRecette> lignes);

    default BigDecimal computeMontantRestant(LigneRecette ligne) {
        if (ligne.getMontantAttendu() == null) return null;
        BigDecimal encaisse = ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantAttendu().subtract(encaisse).max(BigDecimal.ZERO);
    }
}
