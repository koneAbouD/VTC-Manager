package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.vehicule.Balise;
import com.tmk.vtcmanager.application.ports.persistence.BaliseRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.BaliseJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.BalisePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class BaliseRepositoryAdapter implements BaliseRepository {

    private final BaliseJpaRepository jpaRepository;
    private final BalisePersistenceMapper mapper;

    @Override
    public Balise save(Balise balise) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(balise)));
    }

    @Override
    public List<Balise> findAll() {
        return jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")).stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public List<Balise> findAllActifs() {
        return jpaRepository.findByActifTrueOrderByIdentifiantAsc().stream()
                .map(mapper::toDomain)
                .toList();
    }

    @Override
    public Optional<Balise> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public Optional<Balise> findByIdentifiant(String identifiant) {
        return jpaRepository.findByIdentifiant(identifiant).map(mapper::toDomain);
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
    public boolean existsByIdentifiant(String identifiant) {
        return jpaRepository.existsByIdentifiant(identifiant);
    }
}
