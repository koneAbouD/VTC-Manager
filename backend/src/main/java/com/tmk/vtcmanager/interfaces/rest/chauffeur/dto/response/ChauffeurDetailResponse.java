package com.tmk.vtcmanager.interfaces.rest.chauffeur.dto.response;

import com.tmk.vtcmanager.application.domain.chauffeur.ChauffeurStatus;
import com.tmk.vtcmanager.application.domain.chauffeur.Genre;
import com.tmk.vtcmanager.application.domain.chauffeur.TypeChauffeur;
import com.tmk.vtcmanager.interfaces.rest.document.dto.DocumentResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.ProgrammeTravailResponse;
import com.tmk.vtcmanager.interfaces.rest.vehicule.dto.response.VehiculeResponse;

import java.time.LocalDate;
import java.util.List;

public record ChauffeurDetailResponse(
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
        VehiculeResponse vehicule,
        ProgrammeTravailResponse programmeTravail) {

    public static ChauffeurDetailResponse from(
            ChauffeurResponse c,
            ProgrammeTravailResponse p,
            List<DocumentResponse> documents) {
        return new ChauffeurDetailResponse(
                c.id(), c.nom(), c.prenom(), c.genre(), c.type(),
                c.dateNaissance(), c.age(), c.photoUrl(),
                documents,
                c.telephone(), c.email(), c.adresse(), c.statut(), c.dateEmbauche(),
                c.geolocalisation(), c.vehicule(), p);
    }
}
