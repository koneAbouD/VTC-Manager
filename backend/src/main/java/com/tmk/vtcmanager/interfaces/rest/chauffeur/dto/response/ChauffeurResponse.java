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
        LocalDate dateEmbauche,
        GeolocalisationResponse geolocalisation,
        VehiculeResponse vehicule
) {}