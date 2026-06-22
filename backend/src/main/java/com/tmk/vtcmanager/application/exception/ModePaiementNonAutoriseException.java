package com.tmk.vtcmanager.application.exception;

public class ModePaiementNonAutoriseException extends RuntimeException {

    public ModePaiementNonAutoriseException(String modeUtilise, String modeAutorise) {
        super("Mode de paiement '" + modeUtilise + "' non autorisé pour ce véhicule. Mode configuré : " + modeAutorise + ".");
    }
}
