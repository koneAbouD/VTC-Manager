package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UploadDocumentUseCase {

    private final DocumentRepository documentRepository;
    private final FileStoragePort fileStoragePort;

    public Document execute(Document document, InputStream fichier, long taille, String contentType) {
        String objectName = UUID.randomUUID() + "/" + document.getFichierNom();
        String url = fileStoragePort.upload(objectName, fichier, taille, contentType);

        document.setFichierUrl(objectName);
        document.setFichierType(contentType);
        document.setStatut(DocumentStatut.EN_ATTENTE);

        return documentRepository.save(document);
    }
}