package com.tmk.vtcmanager.application.domain.chauffeur;

/**
 * Politique de calcul du statut d'un chauffeur à partir de ses signaux métier.
 * <p>
 * Fonction pure (sans dépendance Spring/JPA), testable en isolation. Ne calcule
 * que les statuts <b>dérivables</b> : {@code EN_CONGE} (indisponibilité active)
 * et {@code ACTIF} par défaut. Les statuts décidés par un humain
 * ({@code INACTIF}, {@code SUSPENDU}) sont gérés en amont comme statut manuel
 * verrouillant par {@link Chauffeur#appliquerStatutCalcule(boolean)}.
 */
public final class ChauffeurStatusPolicy {

    private ChauffeurStatusPolicy() {
    }

    public static ChauffeurStatus compute(boolean enConge) {
        return enConge ? ChauffeurStatus.EN_CONGE : ChauffeurStatus.ACTIF;
    }
}
