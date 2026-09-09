package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.StatutLigneCotisation;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.operation.ModePaiement;
import com.tmk.vtcmanager.application.domain.penalite.EncaissementPenalite;
import com.tmk.vtcmanager.application.domain.penalite.LignePenalite;
import com.tmk.vtcmanager.application.domain.penalite.StatutLignePenalite;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.domain.recette.StatutLigneRecette;
import com.tmk.vtcmanager.application.exception.EcritureFigeeException;
import com.tmk.vtcmanager.application.ports.persistence.ArreteCompteRepository;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * Ce qui autorise — ou non — à corriger la date d'un versement déjà enregistré.
 *
 * <p>Redater un encaissement ne change aucun montant : la créance reste due du
 * même montant, le versement reste du même montant. Ce qui bouge, c'est le
 * <em>jour</em> où l'argent est réputé entré — donc l'écriture d'encaissement au
 * journal des opérations, le solde de trésorerie à date, le compte de résultat
 * du mois, l'ancienneté de la créance dans la balance âgée et, pour une
 * cotisation, la date à laquelle le dépôt est réputé détenu. La correction est
 * donc légitime tant qu'aucun document arrêté n'a déjà consigné l'ancienne date.
 *
 * <p>Trois familles de refus, dans l'ordre où elles se lisent :
 * <ul>
 *   <li><b>la ligne</b> — annulée, ou déjà prise dans un arrêté de compte : le
 *       décompte est parti avec cette date, et il nomme un chauffeur ;</li>
 *   <li><b>le versement</b> — extourné, ou couvert par un arrêté à sa date
 *       actuelle : un procès-verbal l'a compté ce jour-là ;</li>
 *   <li><b>la date visée</b> — un arrêté la couvre déjà : y déplacer l'écriture
 *       ferait mentir un état publié.</li>
 * </ul>
 *
 * <p>Comme {@link ReaffectationChauffeurService}, le même service sert deux
 * fois : il refuse côté serveur, et il dit au client quels versements offrir à
 * la correction — un geste voué au refus n'a pas à s'afficher.
 */
@RequiredArgsConstructor
public class ModificationDateEncaissementService {

    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final VerrouArreteService verrouArreteService;
    private final ArreteCompteRepository arreteCompteRepository;
    private final CompteTresorerieResolver compteTresorerieResolver;

    // ── Famille 1 : ce qui ferme la ligne entière ───────────────────────────

    /** Ce qui interdit de redater les versements de cette recette, ou null. */
    public String motifBlocage(LigneRecette ligne) {
        if (ligne.getStatut() == StatutLigneRecette.ANNULEE) {
            return "Cette recette est annulée : ses versements ne comptent plus. Restaurez-la"
                    + " d'abord si la date d'un encaissement doit être corrigée.";
        }
        if (arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.RECETTE, ligne.getId())) {
            return "Un arrêté de compte a déjà compensé cette recette avec le dépôt du chauffeur."
                    + " Le décompte est parti avec les dates de ces versements : elles ne peuvent"
                    + " plus changer. Annulez l'arrêté si le décompte était faux.";
        }
        return null;
    }

    /** Ce qui interdit de redater les versements de cette cotisation, ou null. */
    public String motifBlocage(LigneCotisation ligne) {
        if (ligne.getStatut() == StatutLigneCotisation.ANNULEE) {
            return "Cette cotisation est annulée : ses versements ne comptent plus. Restaurez-la"
                    + " d'abord si la date d'un encaissement doit être corrigée.";
        }
        // Comme pour la réaffectation : le statut et l'arrêté rattaché disent la
        // même chose par deux chemins, et une ligne partiellement restituée
        // reste PARTIELLEMENT_ENCAISSE tout en portant déjà un arrete_id.
        if (ligne.getStatut() == StatutLigneCotisation.RESTITUEE || ligne.getArreteId() != null) {
            return "Un arrêté de compte a déjà restitué tout ou partie de cette cotisation. Le"
                    + " décompte est parti avec les dates de ces versements : elles ne peuvent"
                    + " plus changer. Annulez l'arrêté si le décompte était faux.";
        }
        return null;
    }

    /** Ce qui interdit de redater les versements de cette pénalité, ou null. */
    public String motifBlocage(LignePenalite ligne) {
        if (ligne.getStatut() == StatutLignePenalite.ANNULEE) {
            return "Cette pénalité est annulée : ses versements ne comptent plus. Restaurez-la"
                    + " d'abord si la date d'un encaissement doit être corrigée.";
        }
        if (arreteCompteRepository.existeLigneValidePourDocument(
                TypeDocumentCreance.PENALITE, ligne.getId())) {
            return "Un arrêté de compte a déjà compensé cette pénalité avec le dépôt du chauffeur."
                    + " Le décompte est parti avec les dates de ces versements : elles ne peuvent"
                    + " plus changer. Annulez l'arrêté si le décompte était faux.";
        }
        return null;
    }

    // ── Famille 2 : ce qui ferme un versement en particulier ────────────────

    /**
     * Ce qui interdit de bouger ce versement de sa date actuelle, ou null.
     *
     * @param compteId caisse réellement mouvementée par l'écriture ; un
     *                 comptage d'une autre caisse ne la fige pas
     */
    public String motifBlocageVersement(LocalDate dateActuelle, Long compteId, boolean extourne) {
        return motifBlocageVersement(dateActuelle, compteId, extourne, verrouArreteService.verrous());
    }

    private String motifBlocageVersement(LocalDate dateActuelle, Long compteId, boolean extourne,
                                         VerrouArreteService.Verrous verrous) {
        if (extourne) {
            return "Ce versement a été extourné : il ne compte plus dans la ligne, et sa date"
                    + " n'a plus d'effet. Ressaisissez un encaissement à la bonne date.";
        }
        if (verrous.autoriseEcriture(dateActuelle, compteId)) return null;
        return motifVerrou(dateActuelle, compteId, verrous,
                "les états du mois ont été arrêtés avec cet encaissement à cette date",
                "cet encaissement y a été compté, sa date ne bouge plus");
    }

    // ── Famille 3 : ce que la date visée refuse ─────────────────────────────

    /** Ce qui interdit de porter l'écriture à cette date, ou null. */
    public String motifBlocageNouvelleDate(LocalDate nouvelleDate, Long compteId) {
        VerrouArreteService.Verrous verrous = verrouArreteService.verrous();
        if (verrous.autoriseEcriture(nouvelleDate, compteId)) return null;
        return motifVerrou(nouvelleDate, compteId, verrous,
                "les états du mois ont été arrêtés sans cet encaissement, il ne peut pas y être"
                        + " porté",
                "cette journée est close, l'encaissement ne peut pas y être déplacé");
    }

    private String motifVerrou(LocalDate date, Long compteId, VerrouArreteService.Verrous verrous,
                               String finPeriode, String finCaisse) {
        LocalDate finDernierePeriode = verrous.finDernierePeriode();
        if (finDernierePeriode != null && !date.isAfter(finDernierePeriode)) {
            return "Le " + date.format(JOUR) + " appartient à une période comptable clôturée : "
                    + finPeriode + ".";
        }
        LocalDate comptage = verrous.derniereClotureParCompte().get(compteId);
        return "La caisse a été comptée le " + comptage.format(JOUR) + " : pour le "
                + date.format(JOUR) + ", " + finCaisse + ".";
    }

    // ── Marquage : ce que la fiche a le droit de proposer ───────────────────

    /**
     * Renseigne, versement par versement, si sa date reste corrigeable.
     *
     * <p>Les bornes des arrêtés sont lues une seule fois, puis chaque versement
     * se juge en mémoire. La caisse retenue est celle que son mode de paiement
     * désigne — exactement celle que la création de l'écriture a résolue ; le
     * use case, lui, éprouve la caisse réellement portée par l'opération.
     */
    public void marquerVersements(LigneRecette ligne) {
        String motifLigne = motifBlocage(ligne);
        VerrouArreteService.Verrous verrous = verrouArreteService.verrous();
        List<Encaissement> versements = ligne.getEncaissements();
        if (versements == null) return;
        for (Encaissement e : versements) {
            String motif = motifLigne != null ? motifLigne
                    : motifBlocageVersement(e.getDateEncaissement(),
                            compte(e.getModeEncaissement()), e.getAnnuleLe() != null, verrous);
            e.setDateModifiable(motif == null);
            e.setMotifDateNonModifiable(motif);
        }
    }

    /** Voir {@link #marquerVersements(LigneRecette)}. */
    public void marquerVersements(LigneCotisation ligne) {
        String motifLigne = motifBlocage(ligne);
        VerrouArreteService.Verrous verrous = verrouArreteService.verrous();
        List<EncaissementCotisation> versements = ligne.getEncaissements();
        if (versements == null) return;
        for (EncaissementCotisation e : versements) {
            String motif = motifLigne != null ? motifLigne
                    : motifBlocageVersement(e.getDateEncaissement(),
                            compte(e.getModeEncaissement()), e.getAnnuleLe() != null, verrous);
            e.setDateModifiable(motif == null);
            e.setMotifDateNonModifiable(motif);
        }
    }

    /** Voir {@link #marquerVersements(LigneRecette)}. */
    public void marquerVersements(LignePenalite ligne) {
        String motifLigne = motifBlocage(ligne);
        VerrouArreteService.Verrous verrous = verrouArreteService.verrous();
        List<EncaissementPenalite> versements = ligne.getEncaissements();
        if (versements == null) return;
        for (EncaissementPenalite e : versements) {
            String motif = motifLigne != null ? motifLigne
                    : motifBlocageVersement(e.getDateEncaissement(),
                            compte(e.getModeEncaissement()), e.getAnnuleLe() != null, verrous);
            e.setDateModifiable(motif == null);
            e.setMotifDateNonModifiable(motif);
        }
    }

    private Long compte(ModePaiement mode) {
        return compteTresorerieResolver.resoudre(null, mode);
    }

    // ── Refus côté serveur ──────────────────────────────────────────────────

    /** Refuse si cette recette ne laisse plus redater ses versements. */
    public void verifierLigne(LigneRecette ligne) {
        refuser(motifBlocage(ligne));
    }

    /** Refuse si cette cotisation ne laisse plus redater ses versements. */
    public void verifierLigne(LigneCotisation ligne) {
        refuser(motifBlocage(ligne));
    }

    /** Refuse si cette pénalité ne laisse plus redater ses versements. */
    public void verifierLigne(LignePenalite ligne) {
        refuser(motifBlocage(ligne));
    }

    /** Refuse si ce versement ne peut plus quitter sa date actuelle. */
    public void verifierVersement(LocalDate dateActuelle, Long compteId, boolean extourne) {
        refuser(motifBlocageVersement(dateActuelle, compteId, extourne));
    }

    /** Refuse si l'écriture ne peut pas être portée à cette date. */
    public void verifierNouvelleDate(LocalDate nouvelleDate, Long compteId) {
        refuser(motifBlocageNouvelleDate(nouvelleDate, compteId));
    }

    private void refuser(String motif) {
        if (motif != null) throw new EcritureFigeeException(motif);
    }
}
