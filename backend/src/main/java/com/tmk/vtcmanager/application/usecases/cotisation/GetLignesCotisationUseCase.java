package com.tmk.vtcmanager.application.usecases.cotisation;

import com.tmk.vtcmanager.application.common.PageResult;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisationFiltres;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.TotalCotisationParStatut;
import com.tmk.vtcmanager.application.exception.LigneCotisationNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.LigneCotisationRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;

@RequiredArgsConstructor
public class GetLignesCotisationUseCase {

    private final LigneCotisationRepository ligneCotisationRepository;

    public List<LigneCotisation> findByCriteres(LigneCotisationFiltres filtres) {
        return ligneCotisationRepository.findByCriteres(filtres);
    }

    public PageResult<LigneCotisation> findPageByCriteres(LigneCotisationFiltres filtres, int page, int size) {
        return ligneCotisationRepository.findPageByCriteres(filtres, page, size);
    }

    /**
     * Cumuls par statut sur toute la sélection, tous statuts servis même quand
     * aucune ligne ne les porte : un compteur absent laisserait l'écran afficher
     * l'ancien montant de sa pastille.
     */
    public List<TotalCotisationParStatut> totauxParStatut(LigneCotisationFiltres filtres) {
        List<TotalCotisationParStatut> trouves = ligneCotisationRepository.totauxParStatut(filtres);
        return Arrays.stream(StatutLigneCotisation.values())
                .map(statut -> trouves.stream()
                        .filter(t -> t.statut() == statut)
                        .findFirst()
                        .orElseGet(() -> new TotalCotisationParStatut(
                                statut, 0, BigDecimal.ZERO, BigDecimal.ZERO)))
                .toList();
    }

    public LigneCotisation findById(Long id) {
        return ligneCotisationRepository.findById(id)
                .orElseThrow(() -> new LigneCotisationNotFoundException(id));
    }
}
