package com.tmk.vtcmanager.application.exception;

import lombok.Getter;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * Levée lorsqu'on tente d'affecter à un programme un chauffeur suspendu.
 * Porte la date de suspension pour un message explicite ("suspendu depuis le …").
 */
@Getter
public class ChauffeurSuspenduException extends RuntimeException {

    private static final DateTimeFormatter FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final Long chauffeurId;
    private final String chauffeurNom;
    private final LocalDate dateSuspension;

    public ChauffeurSuspenduException(Long chauffeurId, String chauffeurNom, LocalDate dateSuspension) {
        super(buildMessage(chauffeurNom, dateSuspension));
        this.chauffeurId = chauffeurId;
        this.chauffeurNom = chauffeurNom;
        this.dateSuspension = dateSuspension;
    }

    private static String buildMessage(String nom, LocalDate dateSuspension) {
        if (dateSuspension != null) {
            return String.format(
                    "Le chauffeur '%s' est suspendu depuis le %s et ne peut pas être affecté à un programme.",
                    nom, dateSuspension.format(FMT));
        }
        return String.format(
                "Le chauffeur '%s' est suspendu et ne peut pas être affecté à un programme.", nom);
    }
}
