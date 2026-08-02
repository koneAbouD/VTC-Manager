package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.CaisseCreditriceException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Verrou du sens débiteur des comptes sans découvert.
 *
 * <p>Une caisse d'espèces comme un portefeuille mobile money ne peuvent jamais
 * être créditeurs : ni le tiroir ni l'opérateur ne rendent plus qu'ils ne
 * détiennent. Là où une banque consent un découvert — un fait à enregistrer —,
 * un solde négatif y est toujours une erreur de saisie : recette oubliée,
 * dépense en double, compte mal choisi. Le partage est porté par le domaine
 * ({@link TypeCompteTresorerie#supporteDecouvert()}).
 *
 * <p>Le solde est apprécié <em>à la date de l'écriture</em>, puisque c'est ce
 * jour-là que l'argent devait être disponible. Une écriture antidatée est en
 * outre confrontée au solde du jour : sans quoi elle pourrait creuser après coup
 * un compte que les mouvements postérieurs ont déjà vidé.
 */
@RequiredArgsConstructor
public class CaisseCreditriceGuard {

    private final CompteTresorerieRepository compteTresorerieRepository;

    /**
     * @param compteId compte débité ; ignoré s'il est nul (écriture hors caisse)
     * @param montant  montant décaissé, positif ; les encaissements ne concernent
     *                 pas ce contrôle
     * @param date     date de l'écriture
     */
    public void verifier(Long compteId, BigDecimal montant, LocalDate date) {
        if (compteId == null || montant == null || montant.signum() <= 0 || date == null) return;

        verifierALaDate(compteId, montant, date);

        // Antidatage : le solde du jour doit lui aussi rester positif, sinon la
        // caisse deviendrait négative « depuis » cette écriture.
        LocalDate aujourdHui = LocalDate.now();
        if (date.isBefore(aujourdHui)) {
            verifierALaDate(compteId, montant, aujourdHui);
        }
    }

    private void verifierALaDate(Long compteId, BigDecimal montant, LocalDate date) {
        CompteAvecSolde compte = compteTresorerieRepository
                .findAvecSoldeALaDate(compteId, date)
                .orElse(null);
        if (compte == null || compte.getCompte() == null) return;
        TypeCompteTresorerie type = compte.getCompte().getType();
        if (type == null || type.supporteDecouvert()) return;

        BigDecimal solde = compte.getSolde() != null ? compte.getSolde() : BigDecimal.ZERO;
        if (solde.subtract(montant).signum() < 0) {
            throw new CaisseCreditriceException(
                    compte.getCompte().getLibelle(), type, solde, montant, date);
        }
    }
}
