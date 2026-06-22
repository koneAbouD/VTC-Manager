package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class UpdateTypeDocumentUseCase {

    private final TypeDocumentRepository typeDocumentRepository;

    public TypeDocument execute(Long id, TypeDocument update) {
        typeDocumentRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("TypeDocument", id));
        update.setId(id);
        return typeDocumentRepository.save(update);
    }
}