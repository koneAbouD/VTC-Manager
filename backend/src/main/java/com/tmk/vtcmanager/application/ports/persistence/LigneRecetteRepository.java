package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

public interface LigneRecetteRepository {

    LigneRecette save(LigneRecette ligne);

    Optional<LigneRecette> findById(Long id);

    List<LigneRecette> findByCriteres(LigneRecetteFiltres filtres);

    boolean existsByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate date);

    Optional<LigneRecette> findByVehiculeIdAndChauffeurIdAndDateRecette(Long vehiculeId, Long chauffeurId, LocalDate date);

    List<LigneRecette> findByVehiculeIdAndDateRecette(Long vehiculeId, LocalDate date);

    Optional<LigneRecette> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date);

    Optional<LigneRecette> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date);

    void updateStatutAndMontantEncaisse(Long id, StatutLigneRecette statut, java.math.BigDecimal montantEncaisse);

    void deleteById(Long id);
}
