package com.tmk.vtcmanager.application.usecases.arrete;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.DetteRestanteArrete;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.PerimetreArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;
import com.tmk.vtcmanager.application.domain.arrete.SensArrete;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.LigneRecetteFiltres;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.document.ArreteDocumentRenderer;
import com.tmk.vtcmanager.application.ports.persistence.LigneRecetteRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;

/**
 * Produit le décompte PDF d'un arrêté de compte (enrichi du reste à restituer/dû
 * et des recettes annulées du périmètre sur la période), ou son aperçu avant
 * enregistrement pour une sélection de lignes.
 */
@RequiredArgsConstructor
public class GetArreteDecompteUseCase {

    private final GetArreteUseCase getArreteUseCase;
    private final ArreteDocumentRenderer arreteDocumentRenderer;
    private final LigneRecetteRepository ligneRecetteRepository;
    private final CalculerCompteCourantUseCase calculerCompteCourantUseCase;
    private final VehiculeRepository vehiculeRepository;

    public byte[] executer(Long arreteId) {
        ArreteCompte arrete = getArreteUseCase.detail(arreteId)
                .orElseThrow(() -> new IllegalArgumentException("Arrêté introuvable : " + arreteId));
        return arreteDocumentRenderer.renderDecomptePdf(arrete, recettesAnnulees(arrete));
    }

    /**
     * Décompte de l'arrêté que l'on s'apprête à valider, restreint aux lignes
     * cochées : le document que l'on remet au chauffeur pour qu'il vérifie
     * avant de signer. Rien n'est enregistré.
     *
     * <p>Au moins une cotisation est exigée, comme pour l'arrêté : sans elle la
     * période ne se resserre sur aucun mois, et le relevé jour par jour
     * couvrirait tout l'intervalle demandé — un siècle quand l'écran vise
     * « tout le fonds ».</p>
     */
    public byte[] apercu(PerimetreArrete perimetre, Long perimetreId,
                         LocalDate debut, LocalDate fin, SelectionArrete selection) {
        if (fin.isBefore(debut)) {
            throw new IllegalArgumentException("La fin de période ne peut précéder son début.");
        }
        ArreteCompte arrete = calculerCompteCourantUseCase.simuler(perimetre, perimetreId, debut, fin, selection);
        boolean aucuneCotisation = arrete.getLignes().stream()
                .noneMatch(l -> l.getSens() == SensArrete.CREDIT);
        if (aucuneCotisation) {
            throw new IllegalArgumentException("Sélectionnez au moins une cotisation pour éditer le décompte.");
        }
        nommer(arrete);
        return arreteDocumentRenderer.renderDecomptePdf(arrete, recettesAnnulees(arrete));
    }

    /**
     * Ce que la lecture d'un arrêté enregistré obtient par jointure : les
     * immatriculations des lignes et le libellé du périmètre.
     */
    private void nommer(ArreteCompte arrete) {
        Map<Long, String> plaques = new HashMap<>();
        Function<Long, String> plaque = id -> id == null ? null
                : plaques.computeIfAbsent(id, k -> vehiculeRepository.findById(k)
                        .map(Vehicule::getImmatriculation).orElse(null));
        for (LigneArrete l : arrete.getLignes()) {
            l.setImmatriculation(plaque.apply(l.getVehiculeId()));
        }
        for (DetteRestanteArrete d : arrete.getDettesRestantes()) {
            d.setImmatriculation(plaque.apply(d.getVehiculeId()));
        }
        arrete.setPerimetreLibelle(arrete.getPerimetre() == PerimetreArrete.VEHICULE
                ? plaque.apply(arrete.getPerimetreId())
                : arrete.getReglements().stream()
                        .filter(r -> arrete.getPerimetreId().equals(r.getChauffeurId()))
                        .map(ReglementArrete::getChauffeurNom)
                        .filter(Objects::nonNull)
                        .findFirst()
                        .orElse(null));
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
