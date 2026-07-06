package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeChauffeur;
import com.tmk.vtcmanager.application.domain.programmeTravail.ProgrammeTravail;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import com.tmk.vtcmanager.application.ports.event.ChauffeurStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.event.VehiculeStatutEventPublisher;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.ProgrammeTravailRepository;
import com.tmk.vtcmanager.application.ports.persistence.VehiculeRepository;
import com.tmk.vtcmanager.application.services.ConfigurationRecetteSynchronizer;
import com.tmk.vtcmanager.application.services.IndisponibiliteNettoyageService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@RequiredArgsConstructor
public class UpdateConditionTravailUseCase {

    private final ConditionTravailRepository conditionTravailRepository;
    private final VehiculeRepository vehiculeRepository;
    private final ProgrammeTravailRepository programmeTravailRepository;
    private final ChauffeurRepository chauffeurRepository;
    private final ConfigurationRecetteSynchronizer configurationRecetteSynchronizer;
    private final IndisponibiliteNettoyageService indisponibiliteNettoyageService;
    private final VehiculeStatutEventPublisher statutEventPublisher;
    private final ChauffeurStatutEventPublisher chauffeurStatutEventPublisher;

    private static final Set<String> TYPES_PENALITE_VALIDES = Arrays.stream(TypePenalite.values())
            .map(Enum::name)
            .collect(Collectors.toSet());

    private static final Set<String> TYPES_SANCTION_VALIDES = Arrays.stream(TypeSanction.values())
            .map(Enum::name)
            .collect(Collectors.toSet());

    @Transactional
    public ConditionTravail execute(Long id, ConditionTravail conditionTravail) {
        conditionTravailRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Condition de travail introuvable : " + id));
        conditionTravail.setId(id);
        validate(conditionTravail);
        sanitize(conditionTravail);
        ConditionTravail saved = conditionTravailRepository.save(conditionTravail);

        // Propager les changements à chaque véhicule rattaché à cette condition.
        // - Recette + cotisations : ConfigurationRecette (lue par le contrôle du
        //   mode de paiement à l'encaissement).
        // - Programme de travail + chauffeurs : réaligné sur la condition tout en
        //   conservant l'assignation des chauffeurs.
        // - Pénalités : portées par la condition elle-même (déjà sauvegardée),
        //   donc répercutées automatiquement (rien à faire ici).
        List<Vehicule> vehicules = vehiculeRepository.findByConditionTravailId(id);
        for (Vehicule vehicule : vehicules) {
            Long vehiculeId = vehicule.getId();
            configurationRecetteSynchronizer.synchroniser(vehiculeId, saved);
            programmeTravailRepository.findByVehiculeId(vehiculeId).ifPresent(programme -> {
                programme.synchronizeWithCondition(saved);
                programme.normalize();
                // (2) Réduction du nombre de chauffeurs : retirer les chauffeurs
                // en trop, les dé-affecter et nettoyer leurs indispos orphelines.
                boolean chauffeursRetires = reduireChauffeursSiNecessaire(programme);
                programmeTravailRepository.save(programme);
                // (3) Nettoyer les indispos rendues inertes par le nouveau planning.
                indisponibiliteNettoyageService.nettoyerInertes(programme);
                // (4) Si des chauffeurs ont été dé-affectés, recalculer le statut du véhicule.
                if (chauffeursRetires) {
                    statutEventPublisher.publishStatutDirty(vehiculeId);
                }
            });
        }

        return saved;
    }

    /**
     * Si le programme contient plus de chauffeurs que le nombre désormais
     * autorisé, retire les chauffeurs excédentaires (ordre d'alternance le plus
     * élevé), les dé-affecte du véhicule et nettoie leurs indisponibilités
     * devenues orphelines.
     */
    private boolean reduireChauffeursSiNecessaire(ProgrammeTravail programme) {
        final Integer max = programme.getNombreChauffeursAutorises();
        if (max == null || programme.getChauffeurs() == null
                || programme.getChauffeurs().size() <= max) {
            return false;
        }
        final List<ProgrammeChauffeur> tries = new ArrayList<>(programme.getChauffeurs());
        tries.sort(Comparator.comparing(
                pc -> pc.getOrdreAlternance() == null ? Integer.MAX_VALUE : pc.getOrdreAlternance()));
        final List<Long> retiresIds = tries.subList(max, tries.size()).stream()
                .map(ProgrammeChauffeur::getChauffeurId)
                .filter(Objects::nonNull)
                .toList();

        programme.getChauffeurs().removeIf(pc -> retiresIds.contains(pc.getChauffeurId()));
        programme.normalize();

        for (Long chauffeurId : retiresIds) {
            chauffeurRepository.findById(chauffeurId).ifPresent(c -> {
                c.unassignVehicule();
                chauffeurRepository.save(c);
            });
            indisponibiliteNettoyageService.nettoyerSiOrphelin(chauffeurId);
            // Retiré du véhicule → recalcul du statut chauffeur (→ ACTIF).
            chauffeurStatutEventPublisher.publishStatutDirty(chauffeurId);
        }
        return !retiresIds.isEmpty();
    }

    private void validate(ConditionTravail ct) {
        if (ct.getNbChauffeurs() < 1 || ct.getNbChauffeurs() > 2) {
            throw new IllegalArgumentException("Le nombre de chauffeurs doit être 1 ou 2");
        }
        if (ct.getNbChauffeurs() == 2) {
            if (ct.getModeAlternance() == null || ct.getModeAlternance().isBlank()) {
                throw new IllegalArgumentException("Le mode d'alternance est obligatoire pour 2 chauffeurs");
            }
            if ("AUTOMATIQUE".equals(ct.getModeAlternance())) {
                if (ct.getJoursAlternance() == null || ct.getJoursAlternance() < 1 || ct.getJoursAlternance() > 3) {
                    throw new IllegalArgumentException("Le nombre de jours d'alternance doit être entre 1 et 3");
                }
                if (ct.getDateDebutAlternance() == null) {
                    throw new IllegalArgumentException("La date de début d'alternance est obligatoire en mode automatique");
                }
            }
        }
        if ("MONTANT_FIXE".equals(ct.getTypeRecette())) {
            if (ct.getMontantJourSalaire() == null) {
                throw new IllegalArgumentException("Le montant du jour de salaire est obligatoire pour le type MONTANT_FIXE");
            }
        }
        if ("HEBDOMADAIRE".equals(ct.getFrequenceVersement())) {
            if (ct.getJourVersement() == null || ct.getJourVersement().isBlank()) {
                throw new IllegalArgumentException("Le jour de versement est obligatoire pour une fréquence hebdomadaire");
            }
        }
        if (ct.getPenalites() != null) {
            for (PenaliteTemplate p : ct.getPenalites()) {
                if (!TYPES_PENALITE_VALIDES.contains(p.getTypePenalite())) {
                    throw new IllegalArgumentException("Type de pénalité invalide : " + p.getTypePenalite());
                }
                if (!TYPES_SANCTION_VALIDES.contains(p.getTypeSanction())) {
                    throw new IllegalArgumentException("Type de sanction invalide : " + p.getTypeSanction());
                }
                validateParamSanction(p);
            }
        }
    }

    private void validateParamSanction(PenaliteTemplate p) {
        TypeSanction type = TypeSanction.valueOf(p.getTypeSanction());
        switch (type.paramType) {
            case DUREE_SECONDES -> {
                if (p.getDureeSanctionSecondes() == null || p.getDureeSanctionSecondes() <= 0) {
                    throw new IllegalArgumentException(
                            "La durée en secondes est obligatoire et doit être > 0 pour le type BUZZER");
                }
            }
            case MONTANT -> {
                if (p.getMontant() == null || p.getMontant() <= 0) {
                    throw new IllegalArgumentException(
                            "Le montant est obligatoire et doit être > 0 pour le type " + p.getTypeSanction());
                }
            }
            case NONE -> {
                // AVERTISSEMENT : aucun paramètre requis
            }
            case DUREE_MINUTES -> {
                if (p.getDureeImmobilisationMinutes() == null || p.getDureeImmobilisationMinutes() <= 0) {
                    throw new IllegalArgumentException(
                            "La durée d'immobilisation est obligatoire et doit être > 0 pour le type IMMOBILISATION");
                }
            }
        }
    }

    private void sanitize(ConditionTravail ct) {
        if (ct.getNbChauffeurs() == 1) {
            ct.setModeAlternance(null);
            ct.setJoursAlternance(null);
            ct.setDateDebutAlternance(null);
        } else if ("MANUELLE".equals(ct.getModeAlternance())) {
            ct.setJoursAlternance(null);
            ct.setDateDebutAlternance(null);
        }
        if ("MONTANT_REEL".equals(ct.getTypeRecette())) {
            ct.setMontantJourSalaire(null);
            ct.setMontantJourFerie(null);
        }
        if (!ct.isFeriesConsideres()) {
            ct.setMontantJourFerie(null);
        }
        if (!"HEBDOMADAIRE".equals(ct.getFrequenceVersement())) {
            ct.setJourVersement(null);
        }
    }
}
