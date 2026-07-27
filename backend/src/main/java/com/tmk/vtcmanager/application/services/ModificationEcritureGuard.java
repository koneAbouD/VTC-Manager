package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.operation.OperationFinanciere;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ClotureCaisseRepository;
import com.tmk.vtcmanager.application.ports.persistence.CloturePeriodeRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Objects;

/**
 * Ce qu'on a encore le droit de retoucher sur une écriture existante.
 *
 * <p>Trois règles, de la plus ferme à la plus souple :
 * <ol>
 *   <li>une écriture <b>extournée</b> ne se modifie plus : elle a été corrigée
 *       par une contre-passation, la retoucher rendrait le couple incohérent ;</li>
 *   <li>dans une <b>période close</b>, rien n'est modifiable : les états ont été
 *       publiés et archivés ;</li>
 *   <li>sur une <b>caisse déjà comptée</b>, seuls les champs sans effet sur
 *       l'argent restent ouverts — commentaire, chauffeur, véhicule. Le montant,
 *       la date, le type, le mode de paiement et la catégorie sont figés : les
 *       quatre premiers déplacent de la trésorerie, la dernière déplace des
 *       charges et des produits par sa nature de résultat.</li>
 * </ol>
 *
 * <p>Pour corriger un montant figé, la voie est l'extourne puis la ressaisie :
 * elle laisse une trace, la modification en place n'en laisse aucune.
 */
@RequiredArgsConstructor
public class ModificationEcritureGuard {

    private final CloturePeriodeRepository cloturePeriodeRepository;
    private final ClotureCaisseRepository clotureCaisseRepository;

    /**
     * @param existante écriture telle qu'elle est en base
     * @param modifiee  écriture telle qu'on voudrait l'enregistrer
     */
    public void verifier(OperationFinanciere existante, OperationFinanciere modifiee) {
        if (existante.estExtournee()) {
            throw new EcritureFigeeException("Cette écriture a été extournée : elle ne peut plus"
                    + " être modifiée. Ressaisissez une nouvelle opération.");
        }
        if (existante.estUneExtourne()) {
            throw new EcritureFigeeException("Une extourne ne se modifie pas : elle reproduit"
                    + " l'écriture qu'elle corrige.");
        }

        // Règle 2 — période close : ni la date d'origine, ni la date visée.
        verifierPeriode(existante.getDateOperation());
        verifierPeriode(modifiee.getDateOperation());

        // Règle 3 — caisse comptée : on ne bloque que ce qui touche à l'argent.
        if (!toucheALArgent(existante, modifiee)) {
            return;
        }
        verifierCaisse(existante.getCompteTresorerieId(), existante.getDateOperation());
        verifierCaisse(compteVise(existante, modifiee), modifiee.getDateOperation());
    }

    /**
     * Vrai si la modification déplace de la trésorerie ou change la lecture
     * comptable de l'écriture. Un commentaire corrigé, un chauffeur rattaché
     * autrement : non.
     */
    private boolean toucheALArgent(OperationFinanciere existante, OperationFinanciere modifiee) {
        return montantDifferent(existante.getMontant(), modifiee.getMontant())
                || !Objects.equals(existante.getDateOperation(), modifiee.getDateOperation())
                || !Objects.equals(existante.getTypeOperation(), modifiee.getTypeOperation())
                || !Objects.equals(existante.getModePaiement(), modifiee.getModePaiement())
                || compteChange(existante, modifiee)
                || categorieDifferente(existante, modifiee);
    }

    /**
     * Le compte n'est comparé que s'il est fourni : la requête de modification
     * ne le porte pas toujours, et une absence ne veut pas dire un changement.
     */
    private boolean compteChange(OperationFinanciere existante, OperationFinanciere modifiee) {
        Long vise = modifiee.getCompteTresorerieId();
        return vise != null && !Objects.equals(existante.getCompteTresorerieId(), vise);
    }

    /** Compte réellement mouvementé après modification. */
    private Long compteVise(OperationFinanciere existante, OperationFinanciere modifiee) {
        return modifiee.getCompteTresorerieId() != null
                ? modifiee.getCompteTresorerieId()
                : existante.getCompteTresorerieId();
    }

    /** Comparaison par valeur : 5000 et 5000.00 sont le même montant. */
    private boolean montantDifferent(BigDecimal avant, BigDecimal apres) {
        if (avant == null || apres == null) return avant != apres;
        return avant.compareTo(apres) != 0;
    }

    private boolean categorieDifferente(OperationFinanciere existante, OperationFinanciere modifiee) {
        Long avant = existante.getCategorie() != null ? existante.getCategorie().getId() : null;
        Long apres = modifiee.getCategorie() != null ? modifiee.getCategorie().getId() : null;
        return !Objects.equals(avant, apres);
    }

    private void verifierPeriode(LocalDate date) {
        if (date == null) return;
        cloturePeriodeRepository.findDerniere().ifPresent(derniere -> {
            if (!date.isAfter(derniere.finPeriode())) {
                throw new EcritureFigeeException("L'écriture du " + date + " appartient à une"
                        + " période comptable clôturée : elle n'est plus modifiable.");
            }
        });
    }

    private void verifierCaisse(Long compteId, LocalDate date) {
        if (compteId == null || date == null) return;
        clotureCaisseRepository.findDerniereDateCloture(compteId).ifPresent(derniere -> {
            if (!date.isAfter(derniere)) {
                throw new EcritureFigeeException("La caisse de ce compte a été comptée le "
                        + derniere + " : le montant, la date, le type, le mode de paiement et la"
                        + " catégorie de l'écriture du " + date + " sont figés. Extournez-la puis"
                        + " ressaisissez-la si elle doit changer.");
            }
        });
    }
}
