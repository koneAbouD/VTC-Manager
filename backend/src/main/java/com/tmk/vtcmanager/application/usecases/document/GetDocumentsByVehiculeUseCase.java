package com.tmk.vtcmanager.application.usecases.document;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;
import com.tmk.vtcmanager.application.domain.document.DocumentStatut;
import com.tmk.vtcmanager.application.ports.persistence.DocumentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class GetDocumentsByVehiculeUseCase {

    private final DocumentRepository documentRepository;

    public List<Document> execute(Long vehiculeId) {
        return documentRepository.findByCibleAndCibleId(CibleDocument.VEHICULE, vehiculeId)
                .stream()
                .filter(d -> d.getStatut() != DocumentStatut.ARCHIVE)
                .toList();
    }
}
