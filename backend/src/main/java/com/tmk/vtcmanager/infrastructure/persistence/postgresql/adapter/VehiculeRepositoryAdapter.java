package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.domain.vehicule.VehiculeStatus;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConditionTravailEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.VehiculeEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ConditionTravailJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.GroupeVehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.VehiculePersistenceMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Slf4j
@Component
@RequiredArgsConstructor
public class VehiculeRepositoryAdapter implements VehiculeRepository {

    private final VehiculeJpaRepository jpaRepository;
    private final ConditionTravailJpaRepository conditionTravailJpaRepository;
    private final GroupeVehiculeJpaRepository groupeVehiculeJpaRepository;
    private final VehiculePersistenceMapper mapper;

    @Override
    @Transactional
    public Vehicule save(Vehicule vehicule) {
        VehiculeEntity entity = mapper.toEntity(vehicule);
        // Remplace l'objet ConditionTravailEntity (détaché par MapStruct) par
        // un proxy managé. Sans cascade, JPA n'écrit que la FK.
        Long conditionId = vehicule.getConditionTravailId();
        entity.setConditionTravail(conditionId != null
                ? conditionTravailJpaRepository.getReferenceById(conditionId)
                : null);

        Long groupeId = vehicule.getGroupeId();
        entity.setGroupe(groupeId != null
                ? groupeVehiculeJpaRepository.getReferenceById(groupeId)
                : null);

        VehiculeEntity saved = jpaRepository.saveAndFlush(entity);
        log.info("Véhicule {} sauvegardé : condition_travail_id={}",
                saved.getId(),
                saved.getConditionTravail() != null
                        ? saved.getConditionTravail().getId() : null);
        return mapper.toDomain(saved);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Vehicule> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public Optional<Vehicule> findByImmatriculation(String immatriculation) {
        return jpaRepository.findByImmatriculation(immatriculation).map(mapper::toDomain);
    }

    @Override
    @Transactional(readOnly = true)
    public List<Vehicule> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "updatedAt")));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResult<Vehicule> findPage(VehiculeStatus statut, int page, int size) {
        Pageable pageable = PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "updatedAt"));
        Page<VehiculeEntity> result = (statut != null)
                ? jpaRepository.findByStatut(statut, pageable)
                : jpaRepository.findAll(pageable);
        return new PageResult<>(
                mapper.toDomainList(result.getContent()),
                result.getNumber(), result.getSize(), result.getTotalElements());
    }

    @Override
    @Transactional(readOnly = true)
    public List<Vehicule> findByStatut(VehiculeStatus statut) {
        return mapper.toDomainList(jpaRepository.findByStatut(statut, Sort.by(Sort.Direction.DESC, "updatedAt")));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Vehicule> findByDateProchaineMaintenanceLessThanEqual(LocalDate date) {
        return mapper.toDomainList(jpaRepository.findByDateProchaineMaintenanceLessThanEqual(date));
    }

    @Override
    @Transactional(readOnly = true)
    public List<Vehicule> findByConditionTravailId(Long conditionTravailId) {
        return mapper.toDomainList(jpaRepository.findByConditionTravailId(conditionTravailId));
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }

    @Override
    public long countByGroupeId(Long groupeId) {
        return jpaRepository.countByGroupeId(groupeId);
    }
}
