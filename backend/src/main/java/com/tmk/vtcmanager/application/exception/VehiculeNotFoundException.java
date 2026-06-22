package com.tmk.vtcmanager.application.exception;

public class VehiculeNotFoundException extends ResourceNotFoundException {
    public VehiculeNotFoundException(Long id) {
        super("Véhicule introuvable pour l'id " + id);
    }
}
