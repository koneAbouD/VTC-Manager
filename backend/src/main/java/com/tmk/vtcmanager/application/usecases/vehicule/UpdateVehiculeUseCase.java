package com.tmk.vtcmanager.application.usecases.vehicule;

import com.tmk.vtcmanager.application.domain.configurationRecette.ConfigurationRecette;
import com.tmk.vtcmanager.application.domain.configurationRecette.FrequenceVersement;
import com.tmk.vtcmanager.application.domain.configurationRecette.ModeEncaissement;
import com.tmk.vtcmanager.application.domain.configurationRecette.TypeRecetteConfiguration;
import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.CotisationTemplate;
import com.tmk.vtcmanager.application.domain.configurationRecette.CotisationRecette;
import com.tmk.vtcmanager.application.domain.vehicule.*;
import com.tmk.vtcmanager.application.exception.ResourceAlreadyExistsException;
import com.tmk.vtcmanager.application.exception.ResourceNotFoundException;
import com.tmk.vtcmanager.application.exception.VehiculeNotFoundException;
import com.tmk.vtcmanager.application.ports.persistence.*;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.util.ArrayList;
import java.util.List;

@RequiredArgsConstructor
public class UpdateVehiculeUseCase {

    private final VehiculeRepository vehiculeRepository;
    private final TypeActiviteRepository typeActiviteRepository;
    private final GroupeVehiculeRepository groupeVehiculeRepository;
    private final ConditionTravailRepository conditionTravailRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ConfigurationRecetteRepository configurationRecetteRepository;

    @Transactional
    public Vehicule execute(Long id, UpdateVehiculeCommand cmd) {
        Vehicule existing = vehiculeRepository.findById(id)
                .orElseThrow(() -> new VehiculeNotFoundException(id));

        if (cmd.immatriculation() != null && !cmd.immatriculation().equals(existing.getImmatriculation())) {
            vehiculeRepository.findByImmatriculation(cmd.immatriculation()).ifPresent(conflict -> {
                throw ResourceAlreadyExistsException.of("Véhicule", "immatriculation", cmd.immatriculation());
            });
            existing.setImmatriculation(cmd.immatriculation());
        }
        if (cmd.numeroChassis() != null) existing.setNumeroChassis(cmd.numeroChassis());
        if (cmd.numeroTelephoneVehicule() != null) existing.setNumeroTelephoneVehicule(cmd.numeroTelephoneVehicule());
        if (cmd.numeroTelephoneBalise() != null) existing.setNumeroTelephoneBalise(cmd.numeroTelephoneBalise());
        if (cmd.identifiantBalise() != null) existing.setIdentifiantBalise(cmd.identifiantBalise());
        if (cmd.couleur() != null) existing.setCouleur(cmd.couleur());
        if (cmd.kilometrage() != null) existing.setKilometrage(cmd.kilometrage());
        if (cmd.statut() != null) existing.setStatut(cmd.statut());
        if (cmd.dateAchat() != null) existing.setDateAchat(cmd.dateAchat());
        if (cmd.dateProchaineMaintenance() != null) existing.setDateProchaineMaintenance(cmd.dateProchaineMaintenance());
        if (cmd.dateMiseEnCirculation() != null) existing.setDateMiseEnCirculation(cmd.dateMiseEnCirculation());
        if (cmd.dateEntreeFlotte() != null) existing.setDateEntreeFlotte(cmd.dateEntreeFlotte());

        if (cmd.typeActiviteId() != null) {
            TypeActivite typeActivite = typeActiviteRepository.findById(cmd.typeActiviteId())
                    .orElseThrow(() -> ResourceNotFoundException.of("TypeActivite", cmd.typeActiviteId()));
            existing.setActivite(typeActivite);
        }

        if (cmd.groupeId() != null) {
            var groupe = groupeVehiculeRepository.findById(cmd.groupeId())
                    .orElseThrow(() -> ResourceNotFoundException.of("GroupeVehicule", cmd.groupeId()));
            existing.setGroupe(groupe);
        }

        boolean conditionChanged = false;
        if (cmd.conditionTravailId() != null) {
            var condition = conditionTravailRepository.findById(cmd.conditionTravailId())
                    .orElseThrow(() -> ResourceNotFoundException.of("ConditionTravail", cmd.conditionTravailId()));
            Long ancienneConditionId = existing.getConditionTravail() != null
                    ? existing.getConditionTravail().getId() : null;
            conditionChanged = !cmd.conditionTravailId().equals(ancienneConditionId);
            existing.setConditionTravail(condition);
        }

        existing.validateDates();

        Vehicule saved = vehiculeRepository.save(existing);

        // Re-synchroniser le programme et la configuration de recette si la condition a changé
        if (conditionChanged && existing.getConditionTravail() != null) {
            ConditionTravail condition = existing.getConditionTravail();

            programmeTravailRepository.findByVehiculeId(id).ifPresent(programme -> {
                programme.synchronizeWithCondition(condition);
                programme.normalize();
                programmeTravailRepository.save(programme);
            });

            synchroniserConfigurationRecette(id, condition);
        }

        return saved;
    }

    private void synchroniserConfigurationRecette(Long vehiculeId, ConditionTravail condition) {
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

        // Synchroniser les cotisations
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
