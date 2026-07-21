package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneRecetteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneRecetteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LigneRecettePersistenceMapper;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class LigneRecetteRepositoryAdapter implements LigneRecetteRepository {

    private final LigneRecetteJpaRepository jpaRepository;
    private final VehiculeJpaRepository vehiculeJpaRepository;
    private final ChauffeurJpaRepository chauffeurJpaRepository;
    private final LigneRecettePersistenceMapper mapper;

    @Override
    @Transactional
    public LigneRecette save(LigneRecette ligne) {
        LigneRecetteEntity entity = (ligne.getId() != null)
                ? jpaRepository.findById(ligne.getId()).orElseGet(LigneRecetteEntity::new)
                : new LigneRecetteEntity();

        entity.setVehicule(vehiculeJpaRepository.getReferenceById(ligne.getVehiculeId()));
        entity.setChauffeur(chauffeurJpaRepository.getReferenceById(ligne.getChauffeurId()));
        entity.setDateRecette(ligne.getDateRecette());
        entity.setMontantAttendu(ligne.getMontantAttendu());
        entity.setMontantEncaisse(ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO);
        entity.setStatut(ligne.getStatut());
        entity.setMotifAnnulation(ligne.getMotifAnnulation());

        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<LigneRecette> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<LigneRecette> findByCriteres(LigneRecetteFiltres filtres) {
        return mapper.toDomainList(
                jpaRepository.findAll(buildSpec(filtres), Sort.by(Sort.Direction.DESC, "dateRecette")));
    }

    @Override
    public PageResult<LigneRecette> findPageByCriteres(LigneRecetteFiltres filtres, int page, int size) {
        Page<LigneRecette> result = jpaRepository
                .findAll(buildSpec(filtres),
                        PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "dateRecette")))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements());
    }

    private Specification<LigneRecetteEntity> buildSpec(LigneRecetteFiltres filtres) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (filtres.getVehiculeId() != null) {
                predicates.add(cb.equal(root.get("vehicule").get("id"), filtres.getVehiculeId()));
            }
            if (filtres.getChauffeurId() != null) {
                predicates.add(cb.equal(root.get("chauffeur").get("id"), filtres.getChauffeurId()));
            }
            if (filtres.getStatut() != null) {
                predicates.add(cb.equal(root.get("statut"), filtres.getStatut()));
            }
            if (filtres.getDateDebut() != null) {
                predicates.add(cb.greaterThanOrEqualTo(root.get("dateRecette"), filtres.getDateDebut()));
            }
            if (filtres.getDateFin() != null) {
                predicates.add(cb.lessThanOrEqualTo(root.get("dateRecette"), filtres.getDateFin()));
            }
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }

    @Override
    public boolean existsByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate date) {
        return jpaRepository.existsByVehiculeIdAndChauffeurIdAndDateRecette(vehiculeId, chauffeurId, date);
    }

    @Override
    public Optional<LigneRecette> findByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate date) {
        return jpaRepository.findByVehiculeIdAndChauffeurIdAndDateRecette(vehiculeId, chauffeurId, date)
                .map(mapper::toDomain);
    }

    @Override
    public List<LigneRecette> findByVehiculeIdAndDateRecette(Long vehiculeId, LocalDate date) {
        return mapper.toDomainList(jpaRepository.findByVehiculeIdAndDateRecette(vehiculeId, date));
    }

    @Override
    public Optional<LigneRecette> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date) {
        return jpaRepository.findActiveByVehiculeIdAndDate(vehiculeId, date).map(mapper::toDomain);
    }

    @Override
    public Optional<LigneRecette> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date) {
        return jpaRepository.findActiveByChauffeurIdAndDate(chauffeurId, date).map(mapper::toDomain);
    }

    @Override
    @Transactional
    public void updateStatutAndMontantEncaisse(Long id, StatutLigneRecette statut, BigDecimal montantEncaisse) {
        jpaRepository.updateStatutAndMontantEncaisse(id, statut, montantEncaisse);
    }

    @Override
    @Transactional
    public void recalculerDepuisEncaissements(Long ligneId) {
        jpaRepository.recalculerDepuisEncaissements(ligneId);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
