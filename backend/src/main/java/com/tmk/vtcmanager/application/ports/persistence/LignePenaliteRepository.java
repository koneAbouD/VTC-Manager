package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenaliteFiltres;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface LignePenaliteRepository {

    LignePenalite save(LignePenalite ligne);

    Optional<LignePenalite> findById(Long id);

    List<LignePenalite> findByCriteres(LignePenaliteFiltres filtres);

    PageResult<LignePenalite> findPageByCriteres(LignePenaliteFiltres filtres, int page, int size);

    boolean existsDejaGeneree(Long vehiculeId, Long chauffeurId, TypePenalite typePenalite, LocalDate dateFaute);

    boolean hasAmendePendingByVehiculeOrChauffeur(Long vehiculeId, Long chauffeurId);

    /** Indique si une immobilisation pénalité est actuellement en cours sur le véhicule. */
    boolean hasImmobilisationActiveByVehiculeId(Long vehiculeId);

    void updateStatut(Long id, StatutLignePenalite statut);

    void updateStatutAndMontantEncaisse(Long id, StatutLignePenalite statut, BigDecimal montantEncaisse);

    /** Recalcule montant_encaisse + statut (amende) depuis ses encaissements (source de vérité). */
    void recalculerDepuisEncaissements(Long ligneId);

    void updateDebutImmobilisation(Long id, StatutLignePenalite statut, LocalDateTime dateDebut);

    void updateFinImmobilisation(Long id, StatutLignePenalite statut, LocalDateTime dateFin);
}
