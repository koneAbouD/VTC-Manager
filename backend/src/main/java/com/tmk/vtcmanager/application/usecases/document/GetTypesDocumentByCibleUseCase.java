package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetTypesDocumentByCibleUseCase {

    private final TypeDocumentRepository typeDocumentRepository;

    public List<TypeDocument> execute(CibleDocument cible) {
        return typeDocumentRepository.findByCible(cible);
    }
}