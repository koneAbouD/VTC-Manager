package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.CotisationTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ConditionTravailEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.CotisationTemplateEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.PenaliteTemplateEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.ConditionTravailJpaRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.mapper.ConditionTravailPersistenceMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class ConditionTravailRepositoryAdapter implements ConditionTravailRepository {

    private final ConditionTravailJpaRepository conditionTravailJpaRepository;
    private final ConditionTravailPersistenceMapper mapper;

    @Override
    public List<ConditionTravail> findAll() {
        return mapper.toDomainList(conditionTravailJpaRepository.findAll(Sort.by(Sort.Direction.DESC, "updatedAt")));
    }

    @Override
    public Optional<ConditionTravail> findById(Long id) {
        return conditionTravailJpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public Optional<ConditionTravail> findByVehiculeId(Long vehiculeId) {
        return conditionTravailJpaRepository.findByVehiculeId(vehiculeId).map(mapper::toDomain);
    }

    @Override
    @Transactional
    public ConditionTravail save(ConditionTravail conditionTravail) {
        ConditionTravailEntity entity = conditionTravail.getId() != null
                ? conditionTravailJpaRepository.findById(conditionTravail.getId())
                        .orElseGet(ConditionTravailEntity::new)
                : new ConditionTravailEntity();

        // Champs de base
        entity.setNom(conditionTravail.getNom());
        entity.setNbChauffeurs(conditionTravail.getNbChauffeurs());
        entity.setTypeProgramme(conditionTravail.getTypeProgramme());
        entity.setHeureDebutService(conditionTravail.getHeureDebutService());
        entity.setHeureFinService(conditionTravail.getHeureFinService());

        // Alternance
        entity.setModeAlternance(conditionTravail.getModeAlternance());
        entity.setJoursAlternance(conditionTravail.getJoursAlternance());
        entity.setDateDebutAlternance(conditionTravail.getDateDebutAlternance());

        // Salaire
        entity.setJourSalaire(conditionTravail.getJourSalaire());

        // Recette
        entity.setObjectifRecette(conditionTravail.getObjectifRecette());
        entity.setTypeRecette(conditionTravail.getTypeRecette());
        entity.setMontantJourSalaire(conditionTravail.getMontantJourSalaire());
        entity.setModeEncaissement(conditionTravail.getModeEncaissement());
        entity.setFrequenceVersement(conditionTravail.getFrequenceVersement());
        entity.setJourVersement(conditionTravail.getJourVersement());
        entity.setHeureVersement(conditionTravail.getHeureVersement());

        // Jours de travail
        if (entity.getJoursTravail() == null) {
            entity.setJoursTravail(new ArrayList<>());
        }
        entity.getJoursTravail().clear();
        if (conditionTravail.getJoursTravail() != null) {
            entity.getJoursTravail().addAll(conditionTravail.getJoursTravail());
        }

        // Cotisations — clear + rebuild pour gérer orphanRemoval proprement
        if (entity.getCotisations() == null) {
            entity.setCotisations(new ArrayList<>());
        }
        entity.getCotisations().clear();
        if (conditionTravail.getCotisations() != null) {
            for (CotisationTemplate c : conditionTravail.getCotisations()) {
                entity.getCotisations().add(CotisationTemplateEntity.builder()
                        .conditionTravail(entity)
                        .nom(c.getNom())
                        .montant(c.getMontant())
                        .build());
            }
        }

        // Pénalités — clear + rebuild, tous les champs persistés
        if (entity.getPenalites() == null) {
            entity.setPenalites(new ArrayList<>());
        }
        entity.getPenalites().clear();
        if (conditionTravail.getPenalites() != null) {
            for (PenaliteTemplate p : conditionTravail.getPenalites()) {
                entity.getPenalites().add(PenaliteTemplateEntity.builder()
                        .conditionTravail(entity)
                        .typePenalite(p.getTypePenalite())
                        .typeSanction(p.getTypeSanction())
                        .dureeSanctionSecondes(p.getDureeSanctionSecondes())
                        .montant(p.getMontant())
                        .dureeImmobilisationMinutes(p.getDureeImmobilisationMinutes())
                        .build());
            }
        }

        return mapper.toDomain(conditionTravailJpaRepository.save(entity));
    }

    @Override
    public void deleteById(Long id) {
        conditionTravailJpaRepository.deleteById(id);
    }
}
