package com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper;

import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DocumentEntity;
import org.mapstruct.Mapper;

import java.util.List;

@Mapper(componentModel = "spring", uses = {TypeDocumentPersistenceMapper.class})
public interface DocumentPersistenceMapper {

    DocumentEntity toEntity(Document domain);

    Document toDomain(DocumentEntity entity);

    List<Document> toDomainList(List<DocumentEntity> entities);
}