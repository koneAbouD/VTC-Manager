package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenaliteFiltres;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.ports.persistence.LignePenaliteRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LignePenaliteEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LignePenaliteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneRecetteJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.PenaliteTemplateJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LignePenalitePersistenceMapper;
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
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class LignePenaliteRepositoryAdapter implements LignePenaliteRepository {

    private final LignePenaliteJpaRepository jpaRepository;
    private final VehiculeJpaRepository vehiculeJpaRepository;
    private final ChauffeurJpaRepository chauffeurJpaRepository;
    private final PenaliteTemplateJpaRepository penaliteTemplateJpaRepository;
    private final LigneRecetteJpaRepository ligneRecetteJpaRepository;
    private final LignePenalitePersistenceMapper mapper;

    /**
     * Tri d'affichage : date de la faute la plus récente d'abord (nulls en
     * dernier, car dateFaute est optionnelle), puis date de génération en second.
     */
    private static final Sort SORT_RECENT = Sort.by(
            Sort.Order.desc("dateFaute").nullsLast(),
            Sort.Order.desc("dateGeneration"));

    @Override
    @Transactional
    public LignePenalite save(LignePenalite ligne) {
        LignePenaliteEntity entity = (ligne.getId() != null)
                ? jpaRepository.findById(ligne.getId()).orElseGet(LignePenaliteEntity::new)
                : new LignePenaliteEntity();

        entity.setVehicule(vehiculeJpaRepository.getReferenceById(ligne.getVehiculeId()));
        entity.setChauffeur(chauffeurJpaRepository.getReferenceById(ligne.getChauffeurId()));
        entity.setPenaliteTemplate(ligne.getPenaliteTemplateId() != null
                ? penaliteTemplateJpaRepository.getReferenceById(ligne.getPenaliteTemplateId()) : null);
        entity.setTypePenalite(ligne.getTypePenalite());
        entity.setTypeSanction(ligne.getTypeSanction());
        entity.setMontant(ligne.getMontant() != null ? ligne.getMontant() : BigDecimal.ZERO);
        entity.setMontantEncaisse(ligne.getMontantEncaisse() != null ? ligne.getMontantEncaisse() : BigDecimal.ZERO);
        entity.setDureeSanctionSecondes(ligne.getDureeSanctionSecondes());
        entity.setDureeImmobilisationMinutes(ligne.getDureeImmobilisationMinutes());
        entity.setDateDebutImmobilisation(ligne.getDateDebutImmobilisation());
        entity.setDateFinImmobilisation(ligne.getDateFinImmobilisation());
        entity.setDateGeneration(ligne.getDateGeneration());
        entity.setDateFaute(ligne.getDateFaute());
        entity.setLigneRecette(ligne.getLigneRecetteId() != null
                ? ligneRecetteJpaRepository.getReferenceById(ligne.getLigneRecetteId()) : null);
        entity.setStatut(ligne.getStatut());
        entity.setCommentaire(ligne.getCommentaire());
        entity.setMotifAnnulation(ligne.getMotifAnnulation());

        return mapper.toDomain(jpaRepository.save(entity));
    }

    @Override
    public Optional<LignePenalite> findById(Long id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<LignePenalite> findByCriteres(LignePenaliteFiltres filtres) {
        return mapper.toDomainList(jpaRepository.findAll(buildSpec(filtres), SORT_RECENT));
    }

    @Override
    public PageResult<LignePenalite> findPageByCriteres(LignePenaliteFiltres filtres, int page, int size) {
        Page<LignePenalite> result = jpaRepository
                .findAll(buildSpec(filtres),
                        PageRequest.of(page, size, SORT_RECENT))
                .map(mapper::toDomain);
        return new PageResult<>(
                result.getContent(), result.getNumber(), result.getSize(), result.getTotalElements());
    }

    private Specification<LignePenaliteEntity> buildSpec(LignePenaliteFiltres filtres) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (filtres.getVehiculeId() != null)
                predicates.add(cb.equal(root.get("vehicule").get("id"), filtres.getVehiculeId()));
            if (filtres.getChauffeurId() != null)
                predicates.add(cb.equal(root.get("chauffeur").get("id"), filtres.getChauffeurId()));
            if (filtres.getTypeSanction() != null)
                predicates.add(cb.equal(root.get("typeSanction"), filtres.getTypeSanction()));
            if (filtres.getStatut() != null)
                predicates.add(cb.equal(root.get("statut"), filtres.getStatut()));
            if (filtres.getDateDebut() != null)
                predicates.add(cb.greaterThanOrEqualTo(root.get("dateGeneration"), filtres.getDateDebut()));
            if (filtres.getDateFin() != null)
                predicates.add(cb.lessThanOrEqualTo(root.get("dateGeneration"), filtres.getDateFin()));
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }

    @Override
    public boolean existsDejaGeneree(Long vehiculeId, Long chauffeurId,
                                      TypePenalite typePenalite, LocalDate dateFaute) {
        return jpaRepository.existsDejaGeneree(vehiculeId, chauffeurId, typePenalite, dateFaute);
    }

    @Override
    public boolean hasAmendePendingByVehiculeOrChauffeur(Long vehiculeId, Long chauffeurId) {
        return jpaRepository.hasAmendePendingByVehiculeOrChauffeur(
                vehiculeId, chauffeurId,
                TypeSanction.AMENDE,
                List.of(StatutLignePenalite.EN_ATTENTE,
                        StatutLignePenalite.PARTIELLEMENT_ENCAISSEE));
    }

    @Override
    @Transactional(readOnly = true)
    public boolean hasImmobilisationActiveByVehiculeId(Long vehiculeId) {
        return jpaRepository.existsImmobilisationActive(
                vehiculeId,
                TypeSanction.IMMOBILISATION,
                StatutLignePenalite.EN_COURS);
    }

    @Override
    @Transactional
    public void updateStatut(Long id, StatutLignePenalite statut) {
        jpaRepository.updateStatut(id, statut);
    }

    @Override
    @Transactional
    public void updateStatutEtMotifAnnulation(Long id, StatutLignePenalite statut, String motif) {
        jpaRepository.updateStatutEtMotifAnnulation(id, statut, motif);
    }

    @Override
    @Transactional
    public void updateStatutAndMontantEncaisse(Long id, StatutLignePenalite statut, BigDecimal montantEncaisse) {
        jpaRepository.updateStatutAndMontantEncaisse(id, statut, montantEncaisse);
    }

    @Override
    @Transactional
    public void recalculerDepuisEncaissements(Long ligneId) {
        jpaRepository.recalculerDepuisEncaissements(ligneId);
    }

    @Override
    @Transactional
    public void updateDebutImmobilisation(Long id, StatutLignePenalite statut, LocalDateTime dateDebut) {
        jpaRepository.updateDebutImmobilisation(id, statut, dateDebut);
    }

    @Override
    @Transactional
    public void updateFinImmobilisation(Long id, StatutLignePenalite statut, LocalDateTime dateFin) {
        jpaRepository.updateFinImmobilisation(id, statut, dateFin);
    }
}
