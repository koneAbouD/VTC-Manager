package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.CotisationTemplate;
import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.FrequenceVersement;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.ports.persistence.ConfigurationRecetteRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

/// Synchronise la {@link ConfigurationRecette} d'un véhicule à partir de sa
/// {@link ConditionTravail}.
///
/// Source unique de vérité utilisée à la fois lors de la mise à jour d'un
/// véhicule (rattachement d'une condition) et lors de la modification d'une
/// condition de travail (propagation aux véhicules concernés). C'est cette
/// configuration que lit le contrôle du mode de paiement à l'encaissement.
@RequiredArgsConstructor
public class ConfigurationRecetteSynchronizer {

    private final ConfigurationRecetteRepository configurationRecetteRepository;

    public void synchroniser(Long vehiculeId, ConditionTravail condition) {
        ConfigurationRecette config = configurationRecetteRepository
                .findByVehiculeId(vehiculeId)
                .orElseGet(() -> ConfigurationRecette.builder()
                        .vehiculeId(vehiculeId)
                        .cotisations(new ArrayList<>())
                        .build());

        config.setVehiculeId(vehiculeId);
        config.setTypeRecette(resolveTypeRecette(condition.getTypeRecette()));
        config.setModeEncaissement(resolveModeEncaissement(condition.getModeEncaissement()));
        config.setFrequenceVersement(resolveFrequenceVersement(condition.getFrequenceVersement()));
        config.setHeureLimiteVersement(resolveHeure(condition.getHeureVersement()));
        config.setMontantObjectifParChauffeur(condition.getObjectifRecette());
        config.setMontantJourSalaire(condition.getMontantJourSalaire());
        config.setMontantJourFerie(condition.getMontantJourFerie());

        List<CotisationRecette> cotisations = new ArrayList<>();
        if (condition.getCotisations() != null) {
            int ordre = 1;
            for (CotisationTemplate template : condition.getCotisations()) {
                cotisations.add(CotisationRecette.builder()
                        .nom(template.getNom())
                        .montant(template.getMontant())
                        .ordre(ordre++)
                        .build());
            }
        }
        config.setCotisations(cotisations);

        configurationRecetteRepository.save(config);
    }

    private TypeRecetteConfiguration resolveTypeRecette(String value) {
        if ("MONTANT_FIXE".equals(value)) return TypeRecetteConfiguration.MONTANT_FIXE;
        return TypeRecetteConfiguration.MONTANT_REEL;
    }

    private ModeEncaissement resolveModeEncaissement(String value) {
        if (value == null) return ModeEncaissement.LES_DEUX;
        return switch (value.toUpperCase()) {
            case "ESPECES", "ESPECE" -> ModeEncaissement.ESPECES;
            case "MOBILE_MONEY" -> ModeEncaissement.MOBILE_MONEY;
            default -> ModeEncaissement.LES_DEUX;
        };
    }

    private FrequenceVersement resolveFrequenceVersement(String value) {
        if ("HEBDOMADAIRE".equals(value)) return FrequenceVersement.HEBDOMADAIRE;
        if ("MENSUEL".equals(value)) return FrequenceVersement.MENSUEL;
        return FrequenceVersement.JOURNALIER;
    }

    private LocalTime resolveHeure(String heureVersement) {
        if (heureVersement == null || heureVersement.isBlank()) return LocalTime.of(18, 0);
        try {
            return LocalTime.parse(heureVersement);
        } catch (Exception e) {
            return LocalTime.of(18, 0);
        }
    }
}
