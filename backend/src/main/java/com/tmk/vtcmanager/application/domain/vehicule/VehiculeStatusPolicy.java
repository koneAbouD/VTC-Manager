package com.tmk.vtcmanager.application.domain.vehicule;

/**
 * Politique de calcul du statut d'un véhicule à partir de ses signaux métier.
 * <p>
 * Fonction pure (sans dépendance Spring/JPA), donc testable en isolation. Ne gère
 * que les statuts <b>dérivables</b> ; le statut manuel verrouillant
 * (IMMOBILISE pour panne, HORS_PARC) est appliqué en amont par
 * {@link Vehicule#appliquerStatutCalcule(boolean, boolean, boolean)}.
 * <p>
 * Ordre de priorité (du plus fort au plus faible) :
 * immobilisation pénalité active → maintenance en cours → chauffeur affecté → disponible.
 */
public final class VehiculeStatusPolicy {

    private VehiculeStatusPolicy() {
    }

    public static VehiculeStatus compute(boolean immobilisationActive,
                                         boolean maintenanceEnCours,
                                         boolean chauffeurAffecte) {
        if (immobilisationActive) return VehiculeStatus.IMMOBILISE;
        if (maintenanceEnCours)   return VehiculeStatus.EN_MAINTENANCE;
        if (chauffeurAffecte)     return VehiculeStatus.EN_SERVICE;
        return VehiculeStatus.DISPONIBLE;
    }
}
