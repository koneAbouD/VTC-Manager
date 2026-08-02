package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.tresorerie.CompteAvecSolde;
import com.tmk.vtcmanager.application.domain.tresorerie.TypeCompteTresorerie;
import com.tmk.vtcmanager.application.exception.CaisseCreditriceException;
import com.tmk.vtcmanager.application.ports.persistence.CompteTresorerieRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Verrou du sens débiteur des caisses.
 *
 * <p>Un compte d'espèces ne peut jamais être créditeur : le tiroir ne rend pas
 * plus que ce qu'il contient. Là où une banque autorise un découvert, une caisse
 * négative n'est jamais un fait — c'est une erreur de saisie (recette oubliée,
 * dépense en double, compte mal choisi). Le contrôle ne s'applique donc qu'au
 * type {@link TypeCompteTresorerie#CAISSE}.
 *
 * <p>Le solde est apprécié <em>à la date de l'écriture</em>, puisque c'est ce
 * jour-là que l'argent devait être en caisse. Une écriture antidatée est en
 * outre confrontée au solde du jour : sans quoi elle pourrait creuser après coup
 * une caisse que les mouvements postérieurs ont déjà vidée.
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
        if (compte.getCompte().getType() != TypeCompteTresorerie.CAISSE) return;

        BigDecimal solde = compte.getSolde() != null ? compte.getSolde() : BigDecimal.ZERO;
        if (solde.subtract(montant).signum() < 0) {
            throw new CaisseCreditriceException(
                    compte.getCompte().getLibelle(), solde, montant, date);
        }
    }
}
