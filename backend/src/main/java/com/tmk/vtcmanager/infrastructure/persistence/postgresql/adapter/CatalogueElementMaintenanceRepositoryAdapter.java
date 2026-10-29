package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.operation.CatalogueElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.CatalogueElementMaintenanceRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CatalogueElementMaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.CatalogueElementMaintenanceJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.CategorieOperationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.CatalogueElementMaintenancePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class CatalogueElementMaintenanceRepositoryAdapter implements CatalogueElementMaintenanceRepository {

    private final CatalogueElementMaintenanceJpaRepository jpaRepository;
    private final CategorieOperationJpaRepository categorieOperationJpaRepository;
    private final CatalogueElementMaintenancePersistenceMapper mapper;

    @Override
    public CatalogueElementMaintenance save(CatalogueElementMaintenance element) {
        CatalogueElementMaintenanceEntity entity = mapper.toEntity(element);
        // Le type s'écrit par identifiant ; l'association en lecture seule est
        // posée ici pour que l'élément renvoyé porte déjà son libellé.
        entity.setCategorieType(element.getCategorieTypeId() != null
                ? categorieOperationJpaRepository.getReferenceById(element.getCategorieTypeId())
                : null);
        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<CatalogueElementMaintenance> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<CatalogueElementMaintenance> findAll() {
        // Ordre déterministe (createdAt desc, comme les autres référentiels) :
        // sans tri, PostgreSQL renvoie la ligne modifiée à une autre position
        // après un UPDATE (activation/désactivation) → la ligne « sauterait »
        // dans la liste de paramétrage après un toggle.
        return mapper.toDomainList(
                jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")));
    }

    @Override
    public List<CatalogueElementMaintenance> findAllActifs() {
        return mapper.toDomainList(jpaRepository.findByActifTrueOrderByLibelleAsc());
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }

    @Override
    public boolean isReferencedByElementMaintenance(Long id) {
        return jpaRepository.existsInElementMaintenance(id);
    }
}
