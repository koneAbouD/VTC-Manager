package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.TotalCotisationParStatut;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.LigneCotisationEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ChauffeurJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.LigneCotisationJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.VehiculeJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.LigneCotisationPersistenceMapper;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.spec.RechercheVehiculeChauffeur;
import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import jakarta.persistence.criteria.CriteriaBuilder;
import jakarta.persistence.criteria.CriteriaQuery;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Root;
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

    @PersistenceContext
    private EntityManager entityManager;

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
        entity.setMotifAnnulation(ligne.getMotifAnnulation());
        // L'horodatage suit le motif : c'est lui qui dit à partir de quand la
        // ligne a cessé d'être due, et son effacement qui la rend de nouveau
        // exigible à la restauration.
        entity.setAnnuleLe(ligne.getAnnuleLe());

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

    /**
     * Agrégation côté base : un GROUP BY plutôt que le chargement de toutes les
     * lignes, dont l'écran n'a besoin que des sommes. Le statut demandé est
     * volontairement écarté des prédicats — c'est lui que l'utilisateur va
     * choisir à partir de ces compteurs.
     */
    @Override
    public List<TotalCotisationParStatut> totauxParStatut(LigneCotisationFiltres filtres) {
        CriteriaBuilder cb = entityManager.getCriteriaBuilder();
        CriteriaQuery<TotalCotisationParStatut> query =
                cb.createQuery(TotalCotisationParStatut.class);
        Root<LigneCotisationEntity> root = query.from(LigneCotisationEntity.class);

        query.select(cb.construct(TotalCotisationParStatut.class,
                        root.get("statut"),
                        cb.count(root),
                        cb.sum(root.<BigDecimal>get("montantDu")),
                        cb.sum(root.<BigDecimal>get("montantEncaisse"))))
                .where(predicats(filtres, root, cb, false).toArray(new Predicate[0]))
                .groupBy(root.get("statut"));

        return entityManager.createQuery(query).getResultList();
    }

    private Specification<LigneCotisationEntity> buildSpec(LigneCotisationFiltres filtres) {
        return (root, query, cb) ->
                cb.and(predicats(filtres, root, cb, true).toArray(new Predicate[0]));
    }

    /**
     * Prédicats communs à la liste et aux cumuls : un seul endroit à lire pour
     * savoir ce que « le mois affiché » recouvre.
     *
     * @param avecStatut faux pour les cumuls, qui doivent porter sur tous les statuts.
     */
    private List<Predicate> predicats(LigneCotisationFiltres filtres,
                                      Root<LigneCotisationEntity> root,
                                      CriteriaBuilder cb, boolean avecStatut) {
        List<Predicate> predicates = new ArrayList<>();
        if (filtres.getVehiculeId() != null)
            predicates.add(cb.equal(root.get("vehicule").get("id"), filtres.getVehiculeId()));
        if (filtres.getChauffeurId() != null)
            predicates.add(cb.equal(root.get("chauffeur").get("id"), filtres.getChauffeurId()));
        if (avecStatut && filtres.getStatut() != null)
            predicates.add(cb.equal(root.get("statut"), filtres.getStatut()));
        if (filtres.getDateDebut() != null)
            predicates.add(cb.greaterThanOrEqualTo(root.get("dateCotisation"), filtres.getDateDebut()));
        if (filtres.getDateFin() != null)
            predicates.add(cb.lessThanOrEqualTo(root.get("dateCotisation"), filtres.getDateFin()));
        if (RechercheVehiculeChauffeur.estRenseignee(filtres.getRecherche()))
            predicates.add(RechercheVehiculeChauffeur.predicat(root, cb, filtres.getRecherche()));
        return predicates;
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
    @Transactional
    public void marquerRestituee(Long ligneId, Long arreteId, BigDecimal montant) {
        jpaRepository.marquerRestituee(ligneId, arreteId, montant);
    }

    @Override
    @Transactional
    public void annulerRestitution(Long ligneId, BigDecimal montant) {
        jpaRepository.annulerRestitution(ligneId, montant);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }
}
