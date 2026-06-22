package com.tmk.vtcmanager.interfaces.rest.document.mapper;

import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.document.dto.TypeDocumentRequest;
import com.tmk.vtcmanager.interfaces.rest.document.dto.TypeDocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.document.dto.UploadDocumentRequest;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

import java.util.List;

@Mapper(componentModel = "spring")
public interface DocumentRestMapper {

    @Mapping(target = "fichierUrl",
             expression = "java(domain.getFichierUrl() != null ? \"/v1/documents/\" + domain.getId() + \"/download\" : null)")
    DocumentResponse toResponse(Document domain);

    List<DocumentResponse> toResponseList(List<Document> domains);

    TypeDocumentResponse toTypeResponse(TypeDocument domain);

    List<TypeDocumentResponse> toTypeResponseList(List<TypeDocument> domains);

    @Mapping(target = "id", ignore = true)
    TypeDocument toDomain(TypeDocumentRequest request);

    @Mapping(target = "id", ignore = true)
    @Mapping(target = "typeDocument.id", source = "typeDocumentId")
    @Mapping(target = "statut", ignore = true)
    @Mapping(target = "fichierUrl", ignore = true)
    @Mapping(target = "fichierNom", ignore = true)
    @Mapping(target = "fichierType", ignore = true)
    @Mapping(target = "dateArchivage", ignore = true)
    @Mapping(target = "archivedBy", ignore = true)
    @Mapping(target = "raisonArchivage", ignore = true)
    Document toDomain(UploadDocumentRequest request);
}