package com.tmk.vtcmanager.application.domain.chauffeur;

/**
 * Politique de calcul du statut d'un chauffeur à partir de ses signaux métier.
 * <p>
 * Fonction pure (sans dépendance Spring/JPA), testable en isolation. Ne calcule
 * que les statuts <b>dérivables</b>, par priorité :
 * {@code EN_CONGE} (indisponibilité active) &gt; {@code EN_SERVICE} (affecté à un
 * véhicule) &gt; {@code ACTIF} (disponible). Les statuts décidés par un humain
 * ({@code INACTIF}, {@code SUSPENDU}) sont gérés en amont comme statut manuel
 * verrouillant par {@link Chauffeur#appliquerStatutCalcule(boolean, boolean)}.
 */
public final class ChauffeurStatusPolicy {

    private ChauffeurStatusPolicy() {
    }

    public static ChauffeurStatus compute(boolean enConge, boolean affecte) {
        if (enConge) return ChauffeurStatus.EN_CONGE;
        if (affecte) return ChauffeurStatus.EN_SERVICE;
        return ChauffeurStatus.ACTIF;
    }
}
