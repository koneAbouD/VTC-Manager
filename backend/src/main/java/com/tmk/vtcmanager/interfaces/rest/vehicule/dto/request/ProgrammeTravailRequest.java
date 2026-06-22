package com.tmk.vtcmanager.interfaces.rest.vehicule.dto.request;

import com.tmk.vtcmanager.application.domain.programmeTravail.JourSemaine;
import com.tmk.vtcmanager.application.domain.programmeTravail.ModeAlternance;
import com.tmk.vtcmanager.application.domain.programmeTravail.TypeProgrammeTravail;
import com.fasterxml.jackson.annotation.JsonFormat;
import jakarta.validation.Valid;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;

/**
 * Création / mise à jour du programme de travail d'un véhicule.
 *
 * Le programme représente uniquement l'assignation effective des chauffeurs.
 * La configuration (nombre de chauffeurs autorisés, type de programme, horaires,
 * mode d'alternance, jour de salaire...) est dérivée automatiquement de la
 * condition de travail attachée au véhicule.
 *
 * Les champs ci-dessous sont optionnels et conservés pour permettre des cas
 * d'override ponctuels (ex. modification après bascule manuelle). S'ils sont
 * absents, ils sont remplis à partir de la condition de travail du véhicule.
 */
public record ProgrammeTravailRequest(
        Integer nombreChauffeursAutorises,
        TypeProgrammeTravail typeProgramme,
        @JsonFormat(pattern = "HH:mm") LocalTime heureDebutService,
        @JsonFormat(pattern = "HH:mm") LocalTime heureFinService,
        ModeAlternance modeAlternance,
        Integer joursAlternance,
        LocalDate dateDebutAlternance,
        Set<JourSemaine> joursAlternanceSemaine,
        boolean jourSalaireActif,
        JourSemaine jourSalaire,
        @Valid List<ProgrammeChauffeurRequest> chauffeurs
) {}
