package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.CompteTresorerie;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.CompteTresorerieJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.CompteTresoreriePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Component
@RequiredArgsConstructor
public class CompteTresorerieRepositoryAdapter implements CompteTresorerieRepository {

    private final CompteTresorerieJpaRepository jpaRepository;
    private final CompteTresoreriePersistenceMapper mapper;

    @Override
    public CompteTresorerie save(CompteTresorerie compte) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(compte)));
    }

    @Override
    public Optional<CompteTresorerie> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public Optional<CompteTresorerie> findByCode(String code) {
        return jpaRepository.findByCode(code).map(mapper::toDomain);
    }

    @Override
    public List<CompteTresorerie> findAll() {
        return mapper.toDomainList(jpaRepository.findAll());
    }

    @Override
    public List<CompteTresorerie> findByActifTrue() {
        return mapper.toDomainList(jpaRepository.findByActifTrueOrderByLibelle());
    }

    @Override
    public Optional<CompteTresorerie> findParDefautByType(TypeCompteTresorerie type) {
        return jpaRepository.findByTypeAndParDefautTrue(type).map(mapper::toDomain);
    }

    @Override
    public long countActifsByType(TypeCompteTresorerie type) {
        return jpaRepository.countByTypeAndActifTrue(type);
    }

    @Override
    public boolean existsByCode(String code) {
        return jpaRepository.existsByCode(code);
    }

    @Override
    public Optional<CompteAvecSolde> findAvecSoldeById(Long id) {
        return findAllAvecSoldes(false).stream()
                .filter(c -> c.getCompte().getId().equals(id))
                .findFirst();
    }

    @Override
    public List<CompteAvecSolde> findAllAvecSoldes(boolean actifsSeulement) {
        Map<Long, BigDecimal> soldes = jpaRepository.calculerSoldes(actifsSeulement).stream()
                .collect(Collectors.toMap(
                        CompteTresorerieJpaRepository.SoldeCompteProjection::getCompteId,
                        CompteTresorerieJpaRepository.SoldeCompteProjection::getSolde));

        List<CompteTresorerie> comptes = actifsSeulement
                ? findByActifTrue()
                : findAll();

        return comptes.stream()
                .map(c -> CompteAvecSolde.builder()
                        .compte(c)
                        .solde(soldes.getOrDefault(c.getId(), c.getSoldeInitial()))
                        .build())
                .toList();
    }
}
