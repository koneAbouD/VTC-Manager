package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.MaintenanceSpecs;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DetailMaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.MaintenanceJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.MaintenancePersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class MaintenanceRepositoryAdapter implements MaintenanceRepository {

    private final MaintenanceJpaRepository jpaRepository;
    private final MaintenancePersistenceMapper mapper;

    @Override
    public Maintenance save(Maintenance maintenance) {
        MaintenanceEntity entity = mapper.toEntity(maintenance);
        // La clé étrangère des lignes est portée par l'enfant : sans ce
        // rattachement, elles partent avec detail_maintenance_id nul.
        DetailMaintenanceEntity detail = entity.getDetailMaintenance();
        if (detail != null) detail.rattacherElements();
        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<Maintenance> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Maintenance> findAll() {
        return mapper.toDomainList(jpaRepository.findAll(Sort.by(Sort.Direction.DESC, "createdAt")));
    }

    @Override
    public List<Maintenance> findByVehiculeId(Long vehiculeId) {
        return mapper.toDomainList(jpaRepository.findByVehiculeIdOrderByCreatedAtDesc(vehiculeId));
    }

    @Override
    public List<Maintenance> findByStatut(MaintenanceStatus statut) {
        return mapper.toDomainList(jpaRepository.findByStatutOrderByCreatedAtDesc(statut));
    }

    @Override
    public boolean existsByVehiculeIdAndStatut(Long vehiculeId, MaintenanceStatus statut) {
        return jpaRepository.existsByVehiculeIdAndStatut(vehiculeId, statut);
    }

    @Override
    public List<Maintenance> findByType(String type) {
        return mapper.toDomainList(jpaRepository.findByType(type));
    }

    @Override
    public List<Maintenance> findByDatePrevueLessThanEqualAndStatut(LocalDate date, MaintenanceStatus statut) {
        return mapper.toDomainList(jpaRepository.findByDatePrevueLessThanEqualAndStatut(date, statut));
    }

    @Override
    public List<Maintenance> findByFiltres(LocalDate dateDebut, LocalDate dateFin, MaintenanceStatus statut, Long vehiculeId) {
        return mapper.toDomainList(
                jpaRepository.findAll(MaintenanceSpecs.byFiltres(dateDebut, dateFin, statut, vehiculeId))
        );
    }

    @Override
    public PageResult<Maintenance> findPageByFiltres(LocalDate dateDebut, LocalDate dateFin,
                                                     MaintenanceStatus statut, Long vehiculeId,
                                                     String recherche, int page, int size) {
        // Le tri (datePrevue) est porté par la Specification → PageRequest sans Sort.
        Page<Maintenance> result = jpaRepository
                .findAll(MaintenanceSpecs.byFiltres(dateDebut, dateFin, statut, vehiculeId, recherche),
                        PageRequest.of(page, size))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements());
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
