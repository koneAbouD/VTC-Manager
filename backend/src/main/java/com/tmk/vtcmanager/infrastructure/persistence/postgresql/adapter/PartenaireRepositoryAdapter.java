package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.partenaire.Partenaire;
import com.tmk.vtcmanager.application.ports.persistence.PartenaireRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.PartenaireJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.PartenairePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class PartenaireRepositoryAdapter implements PartenaireRepository {

    private final PartenaireJpaRepository jpaRepository;
    private final PartenairePersistenceMapper mapper;

    @Override
    public Partenaire save(Partenaire partenaire) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(partenaire)));
    }

    @Override
    public Optional<Partenaire> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Partenaire> findAll(boolean actifsSeulement) {
        return mapper.toDomainList(actifsSeulement
                ? jpaRepository.findByActifTrueOrderByNomAsc()
                : jpaRepository.findAllByOrderByNomAsc());
    }

    @Override
    public boolean existsByNom(String nom) {
        return nom != null && jpaRepository.existsByNomIgnoreCase(nom);
    }
}
