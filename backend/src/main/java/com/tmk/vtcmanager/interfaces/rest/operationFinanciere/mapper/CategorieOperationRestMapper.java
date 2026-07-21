package com.tmk.vtcmanager.interfaces.rest.operationFinanciere.mapper;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.request.CategorieOperationRequest;
import com.tmk.vtcmanager.interfaces.rest.operationFinanciere.dto.response.CategorieOperationResponse;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.Named;

import java.util.List;

@Mapper(componentModel = "spring", uses = {SousCategorieOperationRestMapper.class})
public interface CategorieOperationRestMapper {

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "sousCategorie", ignore = true)
    @Mapping(target = "compteComptable", ignore = true)
    CategorieOperation toDomain(CategorieOperationRequest request);

    CategorieOperationResponse toResponse(CategorieOperation domain);

    List<CategorieOperationResponse> toResponseList(List<CategorieOperation> domains);

    @Named("categorieOperationRefFromId")
    default CategorieOperation categorieOperationRefFromId(Long id) {
        if (id == null) return null;
        return CategorieOperation.builder().id(id).build();
    }
}
