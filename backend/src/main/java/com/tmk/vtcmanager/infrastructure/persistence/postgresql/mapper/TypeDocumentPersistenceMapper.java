package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TypeDocumentEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring")
public interface TypeDocumentPersistenceMapper {

    TypeDocumentEntity toEntity(TypeDocument domain);

    TypeDocument toDomain(TypeDocumentEntity entity);

    List<TypeDocument> toDomainList(List<TypeDocumentEntity> entities);
}