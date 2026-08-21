package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.arrete.ArreteCompte;
import com.tmk.vtcmanager.application.domain.arrete.LigneArrete;
import com.tmk.vtcmanager.application.domain.arrete.ReglementArrete;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

/** Persistance des arrêtés de compte (en-tête + lignes snapshot + règlements). */
public interface ArreteCompteRepository {

    /**
     * Prend le verrou qui sérialise l'exécution et l'annulation des arrêtés,
     * jusqu'à la fin de la transaction courante.
     *
     * <p>Une créance ouverte n'est marquée nulle part comme « en cours
     * d'arrêté » : deux arrêtés simultanés — l'un par chauffeur, l'autre par le
     * véhicule qu'il conduit — la voient tous les deux et l'éteignent deux fois.
     * Aucune contrainte de base ne peut le rattraper, le montant encaissé étant
     * recalculé par somme. Les arrêtés se comptent en unités par jour : les
     * sérialiser ne coûte rien et ferme le trou entièrement.
     */
    void verrouillerExecution();

    /** Insère l'en-tête et renvoie l'arrêté avec son id (nécessaire aux FK). */
    ArreteCompte enregistrerEntete(ArreteCompte arrete);

    /** Insère les lignes snapshot (chacune porte son arrete_id). */
    void enregistrerLignes(List<LigneArrete> lignes);

    /** Insère les règlements par bénéficiaire (chacun porte son arrete_id). */
    void enregistrerReglements(List<ReglementArrete> reglements);

    /** Charge l'arrêté complet (en-tête + lignes + règlements). */
    Optional<ArreteCompte> findById(Long id);

    /**
     * Historique, du plus récent au plus ancien, éventuellement restreint aux
     * arrêtés dont la date d'arrêté tombe entre {@code debut} et {@code fin}
     * (bornes incluses ; null = pas de borne).
     */
    List<ArreteCompte> findAll(LocalDate debut, LocalDate fin);

    /** Arrêtés dont un règlement concerne ce chauffeur (relevé de compte). */
    List<ArreteCompte> findByBeneficiaire(Long chauffeurId);

    /** Passe l'arrêté en ANNULE avec son motif. */
    void annuler(Long id, String motif);

    boolean existsByReference(String reference);
}
