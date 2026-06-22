package com.tmk.vtcmanager.interfaces.rest.cotisation.mapper;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.request.EncaissementCotisationRequest;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.EncaissementCotisationResponse;
import com.tmk.vtcmanager.interfaces.rest.cotisation.dto.response.LigneCotisationResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.math.BigDecimal;
import java.util.List;

@Mapper(componentModel = "spring")
public interface CotisationRestMapper {

    @Mapping(target = "id",                  ignore = true)
    @Mapping(target = "ligneCotisationId",    ignore = true)
    @Mapping(target = "operationFinanciereId", ignore = true)
    EncaissementCotisation toDomain(EncaissementCotisationRequest request);

    EncaissementCotisationResponse toResponse(EncaissementCotisation encaissement);

    List<EncaissementCotisationResponse> toEncaissementResponseList(List<EncaissementCotisation> list);

    @Mapping(target = "montantRestant", expression = "java(computeRestant(ligne))")
    LigneCotisationResponse toResponse(LigneCotisation ligne);

    List<LigneCotisationResponse> toResponseList(List<LigneCotisation> lignes);

    default BigDecimal computeRestant(LigneCotisation ligne) {
        BigDecimal encaisse = ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO;
        return ligne.getMontantDu().subtract(encaisse).max(BigDecimal.ZERO);
    }
}
