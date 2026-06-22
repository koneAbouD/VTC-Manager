package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.document.CibleDocument;
import com.tmk.vtcmanager.application.domain.document.TypeDocument;
import com.tmk.vtcmanager.application.ports.persistence.TypeDocumentRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.TypeDocumentJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TypeDocumentPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;


@Repository
@RequiredArgsConstructor
public class TypeDocumentRepositoryAdapter implements TypeDocumentRepository {

    private final TypeDocumentJpaRepository jpaRepository;
    private final TypeDocumentPersistenceMapper mapper;

    @Override
    public TypeDocument save(TypeDocument typeDocument) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(typeDocument)));
    }

    @Override
    public Optional<TypeDocument> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<TypeDocument> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")));
    }

    @Override
    public List<TypeDocument> findByCible(CibleDocument cible) {
        return mapper.toDomainList(jpaRepository.findByCibleOrLesDeux(cible));
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }

    @Override
    public boolean existsById(Long id) {
        return jpaRepository.existsById(id);
    }

    @Override
    public Optional<TypeDocument> findByNom(String nom) {
        return jpaRepository.findByNom(nom).map(mapper::toDomain);
    }
}
