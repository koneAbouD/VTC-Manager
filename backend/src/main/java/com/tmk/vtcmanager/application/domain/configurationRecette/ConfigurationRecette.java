package com.tmk.vtcmanager.application.domain.configurationRecette;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ConfigurationRecette {

    private Long id;
    private Long vehiculeId;
    private ModeEncaissement modeEncaissement;
    private TypeRecetteConfiguration typeRecette;
    private FrequenceVersement frequenceVersement;
    private LocalTime heureLimiteVersement;
    private BigDecimal montantObjectifParChauffeur;
    private BigDecimal montantJourSalaire;
    @Builder.Default
    private List<CotisationRecette> cotisations = new ArrayList<>();

    public static ConfigurationRecette defaultForVehicule(Long vehiculeId) {
        return ConfigurationRecette.builder()
                .vehiculeId(vehiculeId)
                .modeEncaissement(ModeEncaissement.LES_DEUX)
                .typeRecette(TypeRecetteConfiguration.MONTANT_REEL)
                .frequenceVersement(FrequenceVersement.JOURNALIER)
                .heureLimiteVersement(LocalTime.of(18, 30))
                .cotisations(new ArrayList<>())
                .build();
    }

    public void normalize() {
        if (cotisations == null) {
            cotisations = new ArrayList<>();
        }

        cotisations.removeIf(cotisation -> cotisation == null);

        for (int index = 0; index < cotisations.size(); index++) {
            cotisations.get(index).normalize(index + 1);
        }

        if (typeRecette == TypeRecetteConfiguration.MONTANT_REEL) {
            montantObjectifParChauffeur = null;
        }
    }

    public void validate() {
        if (vehiculeId == null) {
            throw new IllegalArgumentException("Le véhicule à configurer est obligatoire.");
        }
        if (modeEncaissement == null) {
            throw new IllegalArgumentException("Le moyen d'encaissement est obligatoire.");
        }
        if (typeRecette == null) {
            throw new IllegalArgumentException("Le type de recette est obligatoire.");
        }
        if (frequenceVersement == null) {
            throw new IllegalArgumentException("La fréquence de versement est obligatoire.");
        }
        if (heureLimiteVersement == null) {
            throw new IllegalArgumentException("L'heure limite de versement est obligatoire.");
        }
        if (typeRecette == TypeRecetteConfiguration.MONTANT_FIXE) {
            if (montantObjectifParChauffeur == null || montantObjectifParChauffeur.signum() <= 0) {
                throw new IllegalArgumentException("L'objectif de recette par chauffeur est obligatoire pour une recette à montant fixe.");
            }
        }
        if (montantJourSalaire != null && montantJourSalaire.signum() < 0) {
            throw new IllegalArgumentException("La recette à payer le jour de salaire doit être positive ou nulle.");
        }

        validateCotisations();
    }

    private void validateCotisations() {
        Set<String> noms = new HashSet<>();
        for (CotisationRecette cotisation : cotisations) {
            cotisation.validate();
            String normalizedName = cotisation.getNom().trim().toLowerCase(Locale.ROOT);
            if (!noms.add(normalizedName)) {
                throw new IllegalArgumentException("Chaque cotisation doit avoir un nom unique.");
            }
        }
    }
}
