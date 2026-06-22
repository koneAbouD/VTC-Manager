package com.tmk.vtcmanager.application.ports.persistence;

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

    List<LigneCotisation> findByVehiculeIdAndDateCotisation(Long vehiculeId, LocalDate date);

    Optional<LigneCotisation> findActiveByVehiculeIdAndDate(Long vehiculeId, LocalDate date);

    Optional<LigneCotisation> findActiveByChauffeurIdAndDate(Long chauffeurId, LocalDate date);

    void updateStatutAndMontantEncaisse(Long id, StatutLigneCotisation statut, BigDecimal montantEncaisse);

    void deleteById(Long id);
}
