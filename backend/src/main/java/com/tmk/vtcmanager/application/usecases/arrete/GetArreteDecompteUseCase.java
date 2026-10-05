package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;

/**
 * Produit le décompte PDF d'un arrêté de compte (enrichi du reste à restituer/dû
 * et des recettes annulées du périmètre sur la période).
 */
@RequiredArgsConstructor
public class GetArreteDecompteUseCase {

    private final GetArreteUseCase getArreteUseCase;
    private final ArreteDocumentRenderer arreteDocumentRenderer;
    private final LigneRecetteRepository ligneRecetteRepository;

    public byte[] executer(Long arreteId) {
        ArreteCompte arrete = getArreteUseCase.detail(arreteId)
                .orElseThrow(() -> new IllegalArgumentException("Arrêté introuvable : " + arreteId));
        return arreteDocumentRenderer.renderDecomptePdf(arrete, recettesAnnulees(arrete));
    }

    /**
     * Lues au rendu, pas figées dans l'arrêté : une recette annulée n'est pas
     * une créance, elle n'a rien à faire dans le snapshot. La période est celle
     * qu'affiche le décompte, le mois entier.
     */
    private List<LigneRecette> recettesAnnulees(ArreteCompte arrete) {
        boolean parVehicule = arrete.getPerimetre() == PerimetreArrete.VEHICULE;
        return ligneRecetteRepository.findByCriteres(LigneRecetteFiltres.builder()
                        .vehiculeId(parVehicule ? arrete.getPerimetreId() : null)
                        .chauffeurId(parVehicule ? null : arrete.getPerimetreId())
                        .statut(StatutLigneRecette.ANNULEE)
                        .dateDebut(arrete.debutMois())
                        .dateFin(arrete.finMois())
                        .build())
                .stream()
                .sorted(Comparator.comparing(LigneRecette::getDateRecette,
                        Comparator.nullsLast(Comparator.<LocalDate>naturalOrder())))
                .toList();
    }
}
