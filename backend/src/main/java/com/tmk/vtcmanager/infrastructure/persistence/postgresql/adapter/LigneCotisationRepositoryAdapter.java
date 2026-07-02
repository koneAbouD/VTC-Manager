package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LigneCotisationPersistenceMapper;
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
public class LigneCotisationRepositoryAdapter implements LigneCotisationRepository {

    private final LigneCotisationJpaRepository jpaRepository;
    private final VehiculeJpaRepository vehiculeJpaRepository;
    private final ChauffeurJpaRepository chauffeurJpaRepository;
    private final LigneCotisationPersistenceMapper mapper;

    @Override
    @Transactional
    public LigneCotisation save(LigneCotisation ligne) {
        LigneCotisationEntity entity = (ligne.getId() != null)
                ? jpaRepository.findById(ligne.getId()).orElseGet(LigneCotisationEntity::new)
                : new LigneCotisationEntity();

        entity.setVehicule(vehiculeJpaRepository.getReferenceById(ligne.getVehiculeId()));
        entity.setChauffeur(chauffeurJpaRepository.getReferenceById(ligne.getChauffeurId()));
        entity.setDateCotisation(ligne.getDateCotisation());
        entity.setNomCotisation(ligne.getNomCotisation());
        entity.setMontantDu(ligne.getMontantDu());
        entity.setMontantEncaisse(ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO);
        entity.setStatut(ligne.getStatut());

        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<LigneCotisation> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<LigneCotisation> findByCriteres(LigneCotisationFiltres filtres) {
        return mapper.toDomainList(
                jpaRepository.findAll(buildSpec(filtres), Sort.by(Sort.Direction.DESC, "dateCotisation")));
    }

    @Override
    public PageResult<LigneCotisation> findPageByCriteres(LigneCotisationFiltres filtres, int page, int size) {
        Page<LigneCotisation> result = jpaRepository
                .findAll(buildSpec(filtres),
                        PageRequest.of(page, size, Sort.by(Sort.Direction.DESC, "dateCotisation")))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements());
    }

    private Specification<LigneCotisationEntity> buildSpec(LigneCotisationFiltres filtres) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (filtres.getVehiculeId() != null)
                predicates.add(cb.equal(root.get("vehicule").get("id"), filtres.getVehiculeId()));
            if (filtres.getChauffeurId() != null)
                predicates.add(cb.equal(root.get("chauffeur").get("id"), filtres.getChauffeurId()));
            if (filtres.getStatut() != null)
                predicates.add(cb.equal(root.get("statut"), filtres.getStatut()));
            if (filtres.getDateDebut() != null)
                predicates.add(cb.greaterThanOrEqualTo(root.get("dateCotisation"), filtres.getDateDebut()));
            if (filtres.getDateFin() != null)
                predicates.add(cb.lessThanOrEqualTo(root.get("dateCotisation"), filtres.getDateFin()));
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }

    @Override
    public List<LigneCotisation> findByVehiculeIdAndDateCotisation(Long vehiculeId, LocalDate date) {
        return mapper.toDomainList(jpaRepository.findByVehiculeIdAndDateCotisation(vehiculeId, date));
    }

    @Override
    public Optional<LigneCotisation> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date) {
        return jpaRepository.findActiveByVehiculeIdAndDate(vehiculeId, date).map(mapper::toDomain);
    }

    @Override
    public Optional<LigneCotisation> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date) {
        return jpaRepository.findActiveByChauffeurIdAndDate(chauffeurId, date).map(mapper::toDomain);
    }

    @Override
    @Transactional
    public void updateStatutAndMontantEncaisse(Long id, StatutLigneCotisation statut, BigDecimal montantEncaisse) {
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
