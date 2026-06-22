package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.operation.CategorieOperation;
import com.tmk.vtcmanager.application.domain.operation.TypeOperation;
import com.tmk.vtcmanager.application.ports.persistence.CategorieOperationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.CategorieOperationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.CategorieOperationPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class CategorieOperationRepositoryAdapter implements CategorieOperationRepository {

    private final CategorieOperationJpaRepository jpaRepository;
    private final CategorieOperationPersistenceMapper mapper;

    @Override
    public CategorieOperation save(CategorieOperation categorie) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(categorie)));
    }

    @Override
    public Optional<CategorieOperation> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<CategorieOperation> findAll() {
        return mapper.toDomainList(jpaRepository.findAll());
    }

    @Override
    public List<CategorieOperation> findByTypeOperation(TypeOperation typeOperation) {
        return mapper.toDomainList(jpaRepository.findByTypeOperation(typeOperation));
    }

    @Override
    public List<CategorieOperation> findBySousCategorieCode(String sousCategorieCode) {
        return mapper.toDomainList(jpaRepository.findBySousCategorieCode(sousCategorieCode));
    }

    @Override
    public List<CategorieOperation> findBySousCategorieLibelle(String libelle) {
        return mapper.toDomainList(jpaRepository.findBySousCategorieLibelle(libelle));
    }

    @Override
    public Optional<CategorieOperation> findByCode(String code) {
        return jpaRepository.findByCode(code).map(mapper::toDomain);
    }

    @Override
    public boolean existsByCode(String code) {
        return jpaRepository.existsByCode(code);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
