package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface LigneCotisationRepository {

    LigneCotisation save(LigneCotisation ligne);

    Optional<LigneCotisation> findById(Long id);

    List<LigneCotisation> findByCriteres(LigneCotisationFiltres filtres);

    PageResult<LigneCotisation> findPageByCriteres(LigneCotisationFiltres filtres, int page, int size);

    List<LigneCotisation> findByVehiculeIdAndDateCotisation(Long vehiculeId, LocalDate date);

    Optional<LigneCotisation> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date);

    Optional<LigneCotisation> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date);

    void updateStatutAndMontantEncaisse(Long id, StatutLigneCotisation statut, BigDecimal montantEncaisse);

    /** Recalcule montant_encaisse + statut de la ligne depuis ses encaissements (source de vérité). */
    void recalculerDepuisEncaissements(Long ligneId);

    void deleteById(Long id);
}
