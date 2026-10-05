package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.payment.TypeCiblePaiement;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.conditionTravail.TypeSanction;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import com.tmk.vtcmanager.application.ports.persistence.PaiementRepository;
import lombok.RequiredArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;

/**
 * Ce qui autorise — ou non — à corriger le montant dû d'une recette ou d'une
 * amende.
 *
 * <p>Contrairement à la réaffectation, qui ne déplace aucun montant, corriger
 * ce qui est dû change la créance du chauffeur, la balance âgée et le résultat
 * du véhicule. La porte se ferme donc dès qu'un document a figé ce montant :
 * période comptable clôturée, ou arrêté de compte qui l'a compensé. Le comptage
 * de caisse ne la ferme pas : il n'engage que l'argent compté.
 *
 * <p>Comme {@link ReaffectationChauffeurService}, le même service sert deux
 * fois : il refuse côté serveur, et il dit à la fiche si elle doit proposer
 * l'action — {@link #motifBlocage} est lu à l'affichage.
 */
@RequiredArgsConstructor
public class ModificationMontantService {

    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final VerrouArreteService verrouArreteService;
    private final ArreteCompteRepository arreteCompteRepository;
    private final PaiementRepository paiementRepository;

    /** Ce qui interdit de corriger le montant attendu de cette recette, ou null. */
    public String motifBlocage(LigneRecette ligne) {
        if (ligne.getStatut() == StatutLigneRecette.ANNULEE) {
            return "Cette recette est annulée : restaurez-la d'abord, puis corrigez son montant.";
        }
        if (ligne.getMontantAttendu() == null) {
            return "Cette recette est au montant réel : elle n'a pas de montant attendu, ce sont"
                    + " les versements qui la font.";
        }
        String verrou = motifVerrouDate(ligne.getDateRecette());
        if (verrou != null) return verrou;

        if (arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.RECETTE, ligne.getId())) {
            return motifArrete("cette recette");
        }
        if (paiementRepository.existeEnCours(TypeCiblePaiement.RECETTE, ligne.getId())) {
            return "Un paiement mobile money est en cours sur cette recette : attendez qu'il"
                    + " aboutisse ou qu'il expire.";
        }
        return null;
    }

    /** Ce qui interdit de corriger le montant de cette pénalité, ou null. */
    public String motifBlocage(LignePenalite ligne) {
        if (!TypeSanction.AMENDE.equals(ligne.getTypeSanction())) {
            return "Seule une amende porte un montant.";
        }
        if (ligne.getStatut() == StatutLignePenalite.ANNULEE) {
            return "Cette pénalité est annulée : restaurez-la d'abord, puis corrigez son montant.";
        }
        String verrou = motifVerrouDate(
                ligne.getDateFaute() != null ? ligne.getDateFaute() : ligne.getDateGeneration());
        if (verrou != null) return verrou;

        if (arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.PENALITE, ligne.getId())) {
            return motifArrete("cette amende");
        }
        return null;
    }

    /**
     * Le nouveau montant doit être positif et couvrir ce qui a déjà été versé :
     * descendre en dessous ferait d'un chauffeur à jour un chauffeur à qui l'on
     * doit de l'argent, sans qu'aucune écriture ne le rembourse.
     */
    public void verifierMontant(BigDecimal nouveau, BigDecimal dejaVerse) {
        if (nouveau == null || nouveau.signum() <= 0) {
            throw new IllegalArgumentException("Le montant doit être supérieur à zéro.");
        }
        BigDecimal verse = dejaVerse != null ? dejaVerse : BigDecimal.ZERO;
        if (nouveau.compareTo(verse) < 0) {
            throw new IllegalArgumentException("Le montant ne peut pas être inférieur à ce qui a"
                    + " déjà été versé (" + verse.stripTrailingZeros().toPlainString() + " FCFA)."
                    + " Annulez d'abord le versement en trop.");
        }
    }

    private static String motifArrete(String quoi) {
        return "Un arrêté de compte a déjà compensé " + quoi + " avec les cotisations du"
                + " chauffeur, et le décompte a été remis. Annulez l'arrêté pour corriger le montant.";
    }

    /**
     * Seule la clôture de période fige le montant : les états du mois ont été
     * publiés avec lui. Le comptage de caisse, lui, n'engage que l'argent
     * compté — et corriger ce qui était dû ne déplace aucun versement.
     */
    private String motifVerrouDate(LocalDate date) {
        LocalDate finPeriode = verrouArreteService.verrous().finDernierePeriode();
        if (date == null || finPeriode == null || date.isAfter(finPeriode)) return null;
        return "Le " + date.format(JOUR) + " appartient à une période comptable clôturée :"
                + " les états du mois ont été arrêtés avec ce montant.";
    }
}
