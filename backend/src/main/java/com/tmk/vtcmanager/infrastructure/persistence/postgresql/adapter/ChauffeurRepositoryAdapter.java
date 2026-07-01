package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ChauffeurEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ChauffeurPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ChauffeurRepositoryAdapter implements ChauffeurRepository {

    private final ChauffeurJpaRepository jpaRepository;
    private final VehiculeJpaRepository vehiculeJpaRepository;
    private final ChauffeurPersistenceMapper mapper;

    @Override
    @Transactional
    public Chauffeur save(Chauffeur chauffeur) {
        if (chauffeur.getId() != null) {
            return jpaRepository.findById(chauffeur.getId())
                    .map(existing -> {
                        applyDomainToEntity(existing, chauffeur);
                        return mapper.toDomain(jpaRepository.save(existing));
                    })
                    .orElseGet(() -> mapper.toDomain(jpaRepository.save(mapper.toEntity(chauffeur))));
        }
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(chauffeur)));
    }

    private void applyDomainToEntity(ChauffeurEntity entity, Chauffeur domain) {
        entity.setNom(domain.getNom());
        entity.setPrenom(domain.getPrenom());
        entity.setGenre(domain.getGenre());
        entity.setType(domain.getType());
        entity.setDateNaissance(domain.getDateNaissance());
        entity.setTelephone(domain.getTelephone());
        entity.setEmail(domain.getEmail());
        entity.setAdresse(domain.getAdresse());
        entity.setStatut(domain.getStatut());
        entity.setStatutManuel(domain.getStatutManuel());
        entity.setDateSuspension(domain.getDateSuspension());
        entity.setDateEmbauche(domain.getDateEmbauche());
        entity.setPhotoUrl(domain.getPhotoUrl());
        if (domain.getVehicule() != null) {
            entity.setVehicule(vehiculeJpaRepository.getReferenceById(domain.getVehicule().getId()));
        } else {
            entity.setVehicule(null);
        }
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Chauffeur> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Chauffeur> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "updatedAt")));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResult<Chauffeur> findPage(ChauffeurStatus statut, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "updatedAt"));
        Page<ChauffeurEntity> result = (statut != null)
                ? jpaRepository.findByStatut(statut, pageable)
                : jpaRepository.findAll(pageable);
        return new PageResult<>(
                mapper.toDomainList(result.getContent()),
                result.getNumber(), result.getSize(), result.getTotalElements());
    }

    @Override
    @Transactional(readOnly = true)
    public List<Chauffeur> findByStatut(ChauffeurStatus statut) {
        return mapper.toDomainList(jpaRepository.findByStatut(statut, Sort.by(Sort.Direction.DESC, "updatedAt")));
    }

    @Override
    @Transactional(readOnly = true)
    public boolean existsByVehiculeId(Long vehiculeId) {
        return jpaRepository.existsByVehiculeId(vehiculeId);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
