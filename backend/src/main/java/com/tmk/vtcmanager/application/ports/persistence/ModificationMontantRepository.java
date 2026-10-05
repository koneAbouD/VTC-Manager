package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.modification.ModificationMontant;

/** Journal des corrections de montant dû (recette attendue, amende). */
public interface ModificationMontantRepository {

    void enregistrer(ModificationMontant modification);
}
