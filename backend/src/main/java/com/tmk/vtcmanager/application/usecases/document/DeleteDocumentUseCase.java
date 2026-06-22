package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import com.tmk.vtcmanager.application.ports.storage.FileStoragePort;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class DeleteDocumentUseCase {

    private final DocumentRepository documentRepository;
    private final FileStoragePort fileStoragePort;

    public void execute(Long documentId) {
        var document = documentRepository.findById(documentId)
                .orElseThrow(() -> ResourceNotFoundException.of("Document", documentId));
        fileStoragePort.delete(document.getFichierUrl());
        documentRepository.deleteById(documentId);
    }
}