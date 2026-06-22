package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CategorieOperationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface CategorieOperationPersistenceMapper {

    @Mapping(target = "sousCategorie", ignore = true)
    CategorieOperationEntity toEntity(CategorieOperation domain);

    @Mapping(target = "sousCategorie", ignore = true)
    CategorieOperation toDomain(CategorieOperationEntity entity);

    List<CategorieOperation> toDomainList(List<CategorieOperationEntity> entities);
}
