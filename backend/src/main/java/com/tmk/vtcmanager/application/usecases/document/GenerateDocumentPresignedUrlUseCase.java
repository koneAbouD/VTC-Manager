package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class GenerateDocumentPresignedUrlUseCase {

    private static final int EXPIRY_SECONDS = 900; // 15 minutes

    private final DocumentRepository documentRepository;
    private final FileStoragePort fileStoragePort;

    public Document execute(Long documentId) {
        Document document = documentRepository.findById(documentId)
                .orElseThrow(() -> ResourceNotFoundException.of("Document", documentId));

        String presignedUrl = fileStoragePort.presignedUrl(document.getFichierUrl(), EXPIRY_SECONDS);
        document.setFichierUrl(presignedUrl);
        return document;
    }
}
