package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.Document;

import java.util.List;
import java.util.Optional;

public interface DocumentRepository {

    Document save(Document document);

    Optional<Document> findById(Long id);

    List<Document> findAll();

    List<Document> findByCibleAndCibleId(CibleDocument cible, Long cibleId);

    void deleteById(Long id);
}
