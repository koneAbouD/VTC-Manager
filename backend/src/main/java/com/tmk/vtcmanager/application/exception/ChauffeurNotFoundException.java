package com.tmk.vtcmanager.application.exception;

public class ChauffeurNotFoundException extends ResourceNotFoundException {
    public ChauffeurNotFoundException(Long id) {
        super("Chauffeur introuvable pour l'id " + id);
    }
}
