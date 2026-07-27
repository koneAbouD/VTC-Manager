package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ClotureCaisseEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ClotureCaisseJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TresoreriePersistenceMappers;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ClotureCaisseRepositoryAdapter implements ClotureCaisseRepository {

    private final ClotureCaisseJpaRepository jpaRepository;
    private final TresoreriePersistenceMappers mapper;

    @Override
    public ClotureCaisse save(ClotureCaisse cloture) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(cloture)));
    }

    @Override
    public boolean existsByCompteIdAndDateCloture(Long compteId, LocalDate date) {
        return jpaRepository.existsByCompteIdAndDateCloture(compteId, date);
    }

    @Override
    public List<ClotureCaisse> findByCompteIdOrderByDateDesc(Long compteId) {
        return mapper.toClotureCaisseDomainList(jpaRepository.findByCompteIdOrderByDateClotureDesc(compteId));
    }

    @Override
    public Optional<LocalDate> findDerniereDateCloture(Long compteId) {
        return jpaRepository.findFirstByCompteIdOrderByDateClotureDesc(compteId)
                .map(ClotureCaisseEntity::getDateCloture);
    }

    @Override
    public Optional<ClotureCaisse> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }
}
