package com.tmk.vtcmanager.application.ports.persistence;

import com.tmk.vtcmanager.application.domain.tresorerie.ClotureCaisse;

import java.time.LocalDate;
import java.util.List;

public interface ClotureCaisseRepository {

    ClotureCaisse save(ClotureCaisse cloture);

    boolean existsByCompteIdAndDateCloture(Long compteId, LocalDate date);

    List<ClotureCaisse> findByCompteIdOrderByDateDesc(Long compteId);

    /**
     * Tous les relevés du compte, retirés compris, du plus récent au plus
     * ancien. Les contrôles ignorent les relevés retirés — mais celui qui doit
     * comprendre pourquoi une journée reste fermée a besoin de les voir, avec
     * leur motif : c'est la seule lecture où ils comptent.
     */
    List<ClotureCaisse> findHistoriqueByCompteId(Long compteId);

    /** Date du dernier comptage du compte, s'il y en a eu un. */
    java.util.Optional<LocalDate> findDerniereDateCloture(Long compteId);

    /**
     * Date du dernier comptage du compte à une date d'arrêté — jusqu'où le
     * solde de ce jour-là est attesté par un comptage réel. Sert la photo de
     * clôture, qui dit ainsi ce qu'elle vaut plutôt que de laisser croire que
     * le solde du 31 a été vérifié le 31.
     */
    java.util.Optional<LocalDate> findDerniereDateClotureALaDate(Long compteId, LocalDate date);

    /**
     * Date du dernier comptage, toutes caisses confondues. Au-delà d'elle, plus
     * aucune journée n'a été arrêtée ; en deçà, la journée est close pour toute
     * l'entreprise.
     */
    java.util.Optional<LocalDate> findDerniereDateClotureToutesCaisses();

    /**
     * Date du dernier comptage de chaque caisse. Une écriture se juge sur la
     * caisse qu'elle mouvemente : un comptage sur la caisse secondaire ne fige
     * pas ce qui est passé par la principale.
     */
    java.util.Map<Long, LocalDate> findDernieresClotureParCompte();

    /**
     * Écarts constatés qui attendent encore leur imputation, toutes caisses
     * confondues, du plus ancien au plus récent — c'est dans cet ordre qu'ils
     * se traitent, et le plus ancien est celui qui bloque la clôture du mois le
     * plus lointain. Les relevés retirés en sont exclus : leur écart n'a plus
     * d'existence.
     */
    List<ClotureCaisse> findEcartsEnAttente();

    java.util.Optional<ClotureCaisse> findById(Long id);
}
