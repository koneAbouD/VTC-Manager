package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.parametre.ParametreGeneral;
import com.tmk.vtcmanager.application.ports.persistence.ParametreGeneralRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ParametreGeneralJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ParametreGeneralPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class ParametreGeneralRepositoryAdapter implements ParametreGeneralRepository {

    private final ParametreGeneralJpaRepository jpaRepository;
    private final ParametreGeneralPersistenceMapper mapper;

    @Override
    public List<ParametreGeneral> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.ASC, "libelle")));
    }

    @Override
    public Optional<ParametreGeneral> findByCle(String cle) {
        return jpaRepository.findById(cle).map(mapper::toDomain);
    }

    @Override
    public ParametreGeneral save(ParametreGeneral parametre) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(parametre)));
    }
}
