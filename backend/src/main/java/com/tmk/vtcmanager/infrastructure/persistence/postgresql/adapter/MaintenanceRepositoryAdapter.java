package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.MaintenanceSpecs;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.maintenance.Maintenance;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceFiltres;
import com.tmk.vtcmanager.application.domain.maintenance.MaintenanceStatus;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParStatut;
import com.tmk.vtcmanager.application.domain.maintenance.TotalMaintenanceParType;
import com.tmk.vtcmanager.application.ports.persistence.MaintenanceRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CategorieOperationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.DetailMaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.MaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.MaintenanceJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.MaintenancePersistenceMapper;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Expression;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class MaintenanceRepositoryAdapter implements MaintenanceRepository {

    private final MaintenanceJpaRepository jpaRepository;
    private final MaintenancePersistenceMapper mapper;

    @PersistenceContext
    private EntityManager entityManager;

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
    public PageResult<Maintenance> findPageByFiltres(MaintenanceFiltres filtres, LocalDate aujourdhui,
                                                     int page, int size) {
        // Le tri (datePrevue) est porté par la Specification → PageRequest sans Sort.
        Page<Maintenance> result = jpaRepository
                .findAll(MaintenanceSpecs.byFiltres(filtres, aujourdhui), PageRequest.of(page, size))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements());
    }

    /**
     * Cumul en base (GROUP BY) plutôt que chargement des lignes. Jointure
     * interne sur la catégorie : une maintenance d'avant les catégories n'a pas
     * de type à présenter en tuile.
     */
    @Override
    public List<TotalMaintenanceParType> totauxParType(MaintenanceFiltres filtres) {
        CriteriaBuilder cb = entityManager.getCriteriaBuilder();
        CriteriaQuery<TotalMaintenanceParType> query = cb.createQuery(TotalMaintenanceParType.class);
        Root<MaintenanceEntity> root = query.from(MaintenanceEntity.class);
        Join<MaintenanceEntity, CategorieOperationEntity> categorie = root.join("categorieType");

        // Seules les terminées ont coûté ; les autres restent hors de la somme.
        Expression<BigDecimal> coutRealise = cb.<BigDecimal>selectCase()
                .when(cb.equal(root.get("statut"), MaintenanceStatus.TERMINEE),
                        root.<BigDecimal>get("cout"))
                .otherwise(cb.nullLiteral(BigDecimal.class));

        query.select(cb.construct(TotalMaintenanceParType.class,
                        categorie.get("id"),
                        categorie.get("code"),
                        categorie.get("libelle"),
                        cb.count(root),
                        cb.sum(coutRealise)))
                .where(MaintenanceSpecs.predicats(filtres, LocalDate.now(), root, query, cb)
                        .toArray(new Predicate[0]))
                .groupBy(categorie.get("id"), categorie.get("code"), categorie.get("libelle"));

        return entityManager.createQuery(query).getResultList();
    }

    @Override
    public List<TotalMaintenanceParStatut> totauxParStatut(MaintenanceFiltres filtres) {
        CriteriaBuilder cb = entityManager.getCriteriaBuilder();
        CriteriaQuery<TotalMaintenanceParStatut> query = cb.createQuery(TotalMaintenanceParStatut.class);
        Root<MaintenanceEntity> root = query.from(MaintenanceEntity.class);

        query.select(cb.construct(TotalMaintenanceParStatut.class,
                        root.get("statut"),
                        cb.count(root)))
                .where(MaintenanceSpecs.predicats(filtres, LocalDate.now(), root, query, cb)
                        .toArray(new Predicate[0]))
                .groupBy(root.get("statut"));

        return entityManager.createQuery(query).getResultList();
    }

    @Override
    public long compter(MaintenanceFiltres filtres, LocalDate aujourdhui) {
        return jpaRepository.count(MaintenanceSpecs.byFiltres(filtres, aujourdhui));
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
