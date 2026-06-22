package com.tmk.vtcmanager.application.domain.groupe;

public enum RoleGestionnaire {
    /** Responsabilité complète : création, modification, suppression */
    RESPONSABLE,
    /** Supervision et accès aux rapports, sans modification structurelle */
    SUPERVISEUR,
    /** Opérations courantes : affectation de courses, suivi en temps réel */
    OPERATEUR
}