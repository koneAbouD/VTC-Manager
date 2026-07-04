package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.tresorerie.TransfertTresorerie;
import com.tmk.vtcmanager.application.ports.persistence.TransfertTresorerieRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.TransfertTresorerieJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TresoreriePersistenceMappers;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
public class TransfertTresorerieRepositoryAdapter implements TransfertTresorerieRepository {

    private final TransfertTresorerieJpaRepository jpaRepository;
    private final TresoreriePersistenceMappers mapper;

    @Override
    public TransfertTresorerie save(TransfertTresorerie transfert) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(transfert)));
    }

    @Override
    public List<TransfertTresorerie> findAllOrderByDateDesc() {
        return mapper.toTransfertDomainList(jpaRepository.findAllByOrderByDateTransfertDescIdDesc());
    }
}
