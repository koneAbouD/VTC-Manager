package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * Active / désactive (soft-disable) un type de document. Permet de retirer un
 * type de la sélection sans le supprimer, préservant les documents existants
 * qui le référencent.
 */
@Service
@RequiredArgsConstructor
public class ChangerActivationTypeDocumentUseCase {

    private final TypeDocumentRepository typeDocumentRepository;

    public TypeDocument execute(Long id, boolean actif) {
        TypeDocument existant = typeDocumentRepository.findById(id)
                .orElseThrow(() -> ResourceNotFoundException.of("Type de document", id));
        existant.changerActivation(actif);
        return typeDocumentRepository.save(existant);
    }
}
