package com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.chauffeur.Genre;
import com.tmk.vtcmanager.application.domain.chauffeur.TypeChauffeur;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.time.LocalDate;
import java.util.List;

public record ChauffeurResponse(
        Long id,
        String nom,
        String prenom,
        Genre genre,
        TypeChauffeur type,
        LocalDate dateNaissance,
        Integer age,
        String photoUrl,
        List<DocumentResponse> documents,
        String telephone,
        String email,
        String adresse,
        ChauffeurStatus statut,
        LocalDate dateSuspension,
        LocalDate dateEmbauche,
        GeolocalisationResponse geolocalisation,
        VehiculeResponse vehicule,
        /**
         * Le chauffeur est-il attendu au volant aujourd'hui — jours de travail
         * du véhicule, tour d'alternance, remplacement d'un titulaire
         * indisponible ? Renseigné par les listes ; nul ailleurs, l'appelant
         * n'ayant alors rien à en déduire.
         */
        Boolean auProgrammeAujourdhui
) {}