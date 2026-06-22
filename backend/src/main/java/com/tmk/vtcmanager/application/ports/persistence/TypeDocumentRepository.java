package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.TypeDocument;

import java.util.List;
import java.util.Optional;


public interface TypeDocumentRepository {

    TypeDocument save(TypeDocument typeDocument);

    Optional<TypeDocument> findById(Long id);

    List<TypeDocument> findAll();

    List<TypeDocument> findByCible(CibleDocument cible);

    void deleteById(Long id);

    boolean existsById(Long id);

    Optional<TypeDocument> findByNom(String nom);
}