package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.fournisseur.Fournisseur;
import com.tmk.vtcmanager.application.ports.persistence.FournisseurRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.FournisseurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.FournisseurPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
@RequiredArgsConstructor
public class FournisseurRepositoryAdapter implements FournisseurRepository {

    private final FournisseurJpaRepository jpaRepository;
    private final FournisseurPersistenceMapper mapper;

    @Override
    public Fournisseur save(Fournisseur fournisseur) {
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(fournisseur)));
    }

    @Override
    public Optional<Fournisseur> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Fournisseur> findAll(boolean actifsSeulement) {
        return mapper.toDomainList(actifsSeulement
                ? jpaRepository.findByActifTrueOrderByNomAsc()
                : jpaRepository.findAllByOrderByNomAsc());
    }

    @Override
    public boolean existsByNom(String nom) {
        return nom != null && jpaRepository.existsByNomIgnoreCase(nom);
    }
}
