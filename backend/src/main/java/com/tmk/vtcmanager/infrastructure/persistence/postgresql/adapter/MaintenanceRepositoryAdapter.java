package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.MaintenanceSpecs;
import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
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
        return mapper.toDomain(jpaRepository.save(mapper.toEntity(maintenance)));
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
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
