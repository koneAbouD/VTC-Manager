package com.tmk.vtcmanager.infrastructure.persistence.postgresql.adapter;

import com.tmk.vtcmanager.application.domain.operation.TarifElementMaintenance;
import com.tmk.vtcmanager.application.ports.persistence.TarifElementMaintenanceRepository;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.ModeleEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.entities.TarifElementMaintenanceEntity;
import com.tmk.vtcmanager.infrastructure.persistence.postgresql.jpa.TarifElementMaintenanceJpaRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class TarifElementMaintenanceRepositoryAdapter implements TarifElementMaintenanceRepository {

    private final TarifElementMaintenanceJpaRepository jpaRepository;

    @Override
    public TarifElementMaintenance save(TarifElementMaintenance tarif) {
        TarifElementMaintenanceEntity entity = tarif.getId() != null
                ? jpaRepository.findById(tarif.getId()).orElseGet(TarifElementMaintenanceEntity::new)
                : new TarifElementMaintenanceEntity();
        entity.setElementId(tarif.getElementId());
        entity.setModeleId(tarif.getModeleId());
        entity.setPrix(tarif.getPrix());
        entity.setImage(tarif.getImage());
        entity.setActif(tarif.isActif());
        TarifElementMaintenanceEntity saved = jpaRepository.save(entity);
        // Relu avec son modèle pour renvoyer les noms de modèle et de marque.
        return jpaRepository.findByElementIdAndModeleIdAvecModele(saved.getElementId(), saved.getModeleId())
                .map(this::toDomain)
                .orElseGet(() -> toDomain(saved));
    }

    @Override
    public List<TarifElementMaintenance> findAll() {
        return jpaRepository.findAllAvecModele().stream().map(this::toDomain).toList();
    }

    @Override
    public List<TarifElementMaintenance> findByElementId(Long elementId) {
        return jpaRepository.findByElementIdAvecModele(elementId).stream().map(this::toDomain).toList();
    }

    @Override
    public List<TarifElementMaintenance> findByModeleId(Long modeleId) {
        return jpaRepository.findByModeleIdAvecModele(modeleId).stream().map(this::toDomain).toList();
    }

    @Override
    public Optional<TarifElementMaintenance> findByElementIdAndModeleId(Long elementId, Long modeleId) {
        return jpaRepository.findByElementIdAndModeleIdAvecModele(elementId, modeleId).map(this::toDomain);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }

    @Override
    public long compterParImage(String image) {
        return jpaRepository.countByImage(image);
    }

    private TarifElementMaintenance toDomain(TarifElementMaintenanceEntity e) {
        ModeleEntity modele = e.getModele();
        boolean modeleCharge = modele != null && org.hibernate.Hibernate.isInitialized(modele);
        var marque = modeleCharge ? modele.getMarque() : null;
        boolean marqueChargee = marque != null && org.hibernate.Hibernate.isInitialized(marque);
        return TarifElementMaintenance.builder()
                .id(e.getId())
                .elementId(e.getElementId())
                .modeleId(e.getModeleId())
                .modeleNom(modeleCharge ? modele.getNom() : null)
                .marqueId(marqueChargee ? marque.getId() : null)
                .marqueNom(marqueChargee ? marque.getNom() : null)
                .prix(e.getPrix())
                .image(e.getImage())
                .actif(e.isActif())
                .build();
    }
}
