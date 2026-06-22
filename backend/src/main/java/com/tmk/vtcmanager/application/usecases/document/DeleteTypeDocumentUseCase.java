package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class DeleteTypeDocumentUseCase {

    private final TypeDocumentRepository typeDocumentRepository;

    public void execute(Long id) {
        if (!typeDocumentRepository.existsById(id)) {
            throw ResourceNotFoundException.of("TypeDocument", id);
        }
        typeDocumentRepository.deleteById(id);
    }
}