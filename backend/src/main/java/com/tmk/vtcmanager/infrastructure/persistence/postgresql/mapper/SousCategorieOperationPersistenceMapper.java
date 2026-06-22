package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CategorieOperationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.SousCategorieOperationEntity;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface SousCategorieOperationPersistenceMapper {

    @Mapping(target = "categorie", expression = "java(categorieRef(domain.getCategorieId()))")
    SousCategorieOperationEntity toEntity(SousCategorieOperation domain);

    @Mapping(target = "categorieId", source = "categorie.id")
    SousCategorieOperation toDomain(SousCategorieOperationEntity entity);

    List<SousCategorieOperation> toDomainList(List<SousCategorieOperationEntity> entities);

    default CategorieOperationEntity categorieRef(Long categorieId) {
        if (categorieId == null) return null;
        CategorieOperationEntity ref = new CategorieOperationEntity();
        ref.setId(categorieId);
        return ref;
    }
}
