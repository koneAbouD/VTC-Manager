package com.tmk.vtcmanager.application.domain.recu;

import com.tmk.vtcmanager.application.domain.versement.NatureImputation;

import java.math.BigDecimal;
import java.time.LocalDate;

/**
 * Une créance soldée, telle que le reçu l'atteste.
 *
 * @param journee           la journée réglée — celle que le chauffeur connaît
 * @param payeLe            le jour où l'argent a été reçu
 * @param referenceEcriture la référence au journal, qui permet de retrouver
 *                          l'écriture en cas de contestation
 * @param referencePaiement la référence saisie au guichet (Mobile Money), ou nulle
 */
public record LigneRecuPaiement(
        String libelle,
        NatureImputation nature,
        LocalDate journee,
        LocalDate payeLe,
        BigDecimal montant,
        String referenceEcriture,
        String referencePaiement
) {}
