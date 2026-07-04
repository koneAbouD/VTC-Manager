package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.finance.CloturePeriode;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.CloturePeriodeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.TresoreriePersistenceMappers;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class CloturePeriodeRepositoryAdapter implements CloturePeriodeRepository {

    private final CloturePeriodeJpaRepository jpaRepository;
    private final TresoreriePersistenceMappers mapper;

    @Override
    public CloturePeriode save(CloturePeriode cloture) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(cloture)));
    }

    @Override
    public boolean existsByAnneeAndMois(int annee, int mois) {
        return jpaRepository.existsByAnneeAndMois(annee, mois);
    }

    @Override
    public Optional<CloturePeriode> findDerniere() {
        return jpaRepository.findFirstByOrderByAnneeDescMoisDesc().map(mapper::toDomain);
    }

    @Override
    public List<CloturePeriode> findAllOrderByPeriodeDesc() {
        return mapper.toCloturePeriodeDomainList(jpaRepository.findAllByOrderByAnneeDescMoisDesc());
    }
}
