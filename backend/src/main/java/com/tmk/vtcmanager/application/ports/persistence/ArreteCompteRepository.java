package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;

import java.util.List;
import java.util.Optional;

/** Persistance des arrêtés de compte (en-tête + lignes snapshot + règlements). */
public interface ArreteCompteRepository {

    /** Insère l'en-tête et renvoie l'arrêté avec son id (nécessaire aux FK). */
    ArreteCompte enregistrerEntete(ArreteCompte arrete);

    /** Insère les lignes snapshot (chacune porte son arrete_id). */
    void enregistrerLignes(List<LigneArrete> lignes);

    /** Insère les règlements par bénéficiaire (chacun porte son arrete_id). */
    void enregistrerReglements(List<ReglementArrete> reglements);

    /** Charge l'arrêté complet (en-tête + lignes + règlements). */
    Optional<ArreteCompte> findById(Long id);

    /** Historique, du plus récent au plus ancien. */
    List<ArreteCompte> findAll();

    /** Arrêtés dont un règlement concerne ce chauffeur (relevé de compte). */
    List<ArreteCompte> findByBeneficiaire(Long chauffeurId);

    /** Passe l'arrêté en ANNULE avec son motif. */
    void annuler(Long id, String motif);

    boolean existsByReference(String reference);
}
