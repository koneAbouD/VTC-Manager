package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.operation.SousCategorieOperation;
import com.tmk.vtcmanager.application.ports.persistence.SousCategorieOperationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.SousCategorieOperationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.SousCategorieOperationPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class SousCategorieOperationRepositoryAdapter implements SousCategorieOperationRepository {

    private final SousCategorieOperationJpaRepository jpaRepository;
    private final SousCategorieOperationPersistenceMapper mapper;

    @Override
    public SousCategorieOperation save(SousCategorieOperation sousCategorie) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(sousCategorie)));
    }

    @Override
    public Optional<SousCategorieOperation> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<SousCategorieOperation> findAll() {
        return mapper.toDomainList(jpaRepository.findAll());
    }

    @Override
    public Optional<SousCategorieOperation> findByCategorieId(Long categorieId) {
        return jpaRepository.findByCategorieId(categorieId).map(mapper::toDomain);
    }

    @Override
    public Optional<SousCategorieOperation> findByCode(String code) {
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
