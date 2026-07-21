package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CreateTypeDocumentUseCase {

    private final TypeDocumentRepository typeDocumentRepository;

    public TypeDocument execute(TypeDocument typeDocument) {
        // Un type nouvellement créé est actif par défaut.
        typeDocument.setActif(true);
        return typeDocumentRepository.save(typeDocument);
    }
}