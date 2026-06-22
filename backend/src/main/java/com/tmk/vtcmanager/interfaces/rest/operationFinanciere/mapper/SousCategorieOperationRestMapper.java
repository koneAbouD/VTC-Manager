package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.SousCategorieOperationRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.SousCategorieOperationResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring")
public interface SousCategorieOperationRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "actif", constant = "true")
    @Mapping(target = "categorieId", ignore = true)
    SousCategorieOperation toDomain(SousCategorieOperationRequest request);

    SousCategorieOperationResponse toResponse(SousCategorieOperation domain);

    List<SousCategorieOperationResponse> toResponseList(List<SousCategorieOperation> domains);

    @Named("sousCategorieOperationRefFromId")
    default SousCategorieOperation sousCategorieOperationRefFromId(Long id) {
        if (id == null) return null;
        return SousCategorieOperation.builder().id(id).build();
    }
}
