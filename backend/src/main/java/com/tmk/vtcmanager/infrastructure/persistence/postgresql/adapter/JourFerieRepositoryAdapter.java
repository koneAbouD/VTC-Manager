package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.jourFerie.JourFerie;
import com.tmk.vtcmanager.application.ports.persistence.JourFerieRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.JourFerieJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.JourFeriePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class JourFerieRepositoryAdapter implements JourFerieRepository {

    private final JourFerieJpaRepository jpaRepository;
    private final JourFeriePersistenceMapper mapper;

    @Override
    public JourFerie save(JourFerie jourFerie) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(jourFerie)));
    }

    @Override
    public Optional<JourFerie> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<JourFerie> findByAnnee(int annee) {
        return mapper.toDomainList(jpaRepository.findByAnneeOrderByDateAsc(annee));
    }

    @Override
    public boolean existsByDate(LocalDate date) {
        return jpaRepository.existsByDate(date);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
