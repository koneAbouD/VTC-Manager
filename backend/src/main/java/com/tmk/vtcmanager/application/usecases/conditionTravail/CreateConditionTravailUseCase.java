package com.tmk.vtcmanager.application.usecases.conditionTravail;

import com.tmk.vtcmanager.application.domain.conditionTravail.ConditionTravail;
import com.tmk.vtcmanager.application.domain.conditionTravail.PenaliteTemplate;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.ports.persistence.ConditionTravailRepository;
import lombok.RequiredArgsConstructor;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

@RequiredArgsConstructor
public class CreateConditionTravailUseCase {

    private final ConditionTravailRepository conditionTravailRepository;

    private static final Set<String> TYPES_PENALITE_VALIDES = Arrays.stream(TypePenalite.values())
            .map(Enum::name)
            .collect(Collectors.toSet());

    private static final Set<String> TYPES_SANCTION_VALIDES = Arrays.stream(TypeSanction.values())
            .map(Enum::name)
            .collect(Collectors.toSet());

    public ConditionTravail execute(ConditionTravail conditionTravail) {
        validate(conditionTravail);
        sanitize(conditionTravail);
        return conditionTravailRepository.save(conditionTravail);
    }

    private void validate(ConditionTravail ct) {
        // Alternance
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

        // Recette
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

        // Pénalités
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
        // Alternance
        if (ct.getNbChauffeurs() == 1) {
            ct.setModeAlternance(null);
            ct.setJoursAlternance(null);
            ct.setDateDebutAlternance(null);
        } else if ("MANUELLE".equals(ct.getModeAlternance())) {
            ct.setJoursAlternance(null);
            ct.setDateDebutAlternance(null);
        }

        // Recette
        if ("MONTANT_REEL".equals(ct.getTypeRecette())) {
            ct.setMontantJourSalaire(null);
        }
        if (!"HEBDOMADAIRE".equals(ct.getFrequenceVersement())) {
            ct.setJourVersement(null);
        }
    }
}
