package com.tmk.vtcmanager.application.domain.contravention;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Contravention {

    private Long id;
    private LocalDate dateInfraction;
    private String typeInfraction;
    private String lieu;
    private String description;
    private BigDecimal montant;

    // ── Champs propres aux contraventions de l'État importées par PDF ──────────
    /** Numéro unique du relevé (clé anti-doublon) ; null pour une saisie manuelle. */
    private String numeroContravention;
    private LocalTime heureInfraction;
    private Integer vitesseRelevee;
    private String codeInfraction;
    /** Clé de l'objet PDF source archivé dans MinIO. */
    private String documentSourcePath;
    /** Mode de rattachement du chauffeur (AUTO via programme, MANUEL, ou A_RATTACHER). */
    private StatutRattachement statutRattachement;

    /** Cotisation prélevée auprès du chauffeur (cas où l'entreprise paye d'avance puis se fait rembourser) */
    private BigDecimal cotisation;

    /** Montant déjà reversé / payé */
    private BigDecimal montantPaye;

    private ContraventionStatus statut;
    /** Jour où le chauffeur a payé l'entreprise. */
    private LocalDate datePaiement;
    /**
     * Jour où l'entreprise a reversé la somme à l'État. Tant qu'elle est nulle,
     * l'argent encaissé est détenu pour le compte de l'État : c'est ce qui rend
     * la dette datable au bilan.
     */
    private LocalDate dateReversement;
    private Chauffeur chauffeur;
    private Vehicule vehicule;

    // ── Annulation ────────────────────────────────────────────────────────────
    /**
     * Moment de l'annulation ; NULL tant que la contravention est due. C'est
     * lui — et non le statut courant — qui décide si elle figure dans un état
     * reconstitué à une date passée.
     */
    private LocalDateTime annuleLe;
    private String motifAnnulation;
    private String annulePar;

    /**
     * Enregistre un paiement (ou versement partiel) et met à jour le statut de la contravention.
     */
    public void enregistrerPaiement(BigDecimal montantVerse) {
        if (montantVerse == null) return;
        BigDecimal courant = this.montantPaye == null ? BigDecimal.ZERO : this.montantPaye;
        this.montantPaye = courant.add(montantVerse);

        if (this.montant != null && this.montantPaye.compareTo(this.montant) >= 0) {
            this.statut = ContraventionStatus.PAYE;
            this.datePaiement = LocalDate.now();
        } else {
            this.statut = ContraventionStatus.PARTIELLEMENT_PAYE;
        }
    }

    /**
     * Contre-passe un paiement (annulation d'un arrêté de compte) : diminue le
     * montant payé et recalcule le statut.
     */
    public void annulerPaiement(BigDecimal montantVerse) {
        if (montantVerse == null) return;
        BigDecimal courant = this.montantPaye == null ? BigDecimal.ZERO : this.montantPaye;
        this.montantPaye = courant.subtract(montantVerse).max(BigDecimal.ZERO);

        if (this.montantPaye.signum() == 0) {
            this.statut = ContraventionStatus.EN_ATTENTE;
            this.datePaiement = null;
        } else if (this.montant != null && this.montantPaye.compareTo(this.montant) >= 0) {
            this.statut = ContraventionStatus.PAYE;
        } else {
            this.statut = ContraventionStatus.PARTIELLEMENT_PAYE;
        }
    }

    /**
     * Marque la contravention comme reversée (par ex. l'entreprise reverse à l'État).
     */
    public void reverser() {
        this.statut = ContraventionStatus.REVERSE;
        // La date de paiement du chauffeur n'est pas touchée : elle date
        // l'encaissement, pas le versement à l'État. Les écraser toutes deux
        // reviendrait à effacer le moment où la dette est née.
        this.dateReversement = LocalDate.now();
    }

    /** Vrai si le chauffeur a déjà versé quelque chose. */
    public boolean aDesVersements() {
        return montantPaye != null && montantPaye.compareTo(BigDecimal.ZERO) > 0;
    }

    public boolean estAnnulee() {
        return statut == ContraventionStatus.ANNULE;
    }

    /**
     * Passe la contravention en ANNULE, motif et auteur à l'appui (validation
     * dans le use case).
     *
     * <p>La contravention n'est pas effacée : elle a figuré à l'actif tant
     * qu'elle était due, et les états déjà arrêtés doivent continuer de la
     * montrer. Seule sa date d'annulation la retire des lectures postérieures.
     */
    public void annuler(String motif, String auteur) {
        this.statut = ContraventionStatus.ANNULE;
        this.motifAnnulation = motif;
        this.annulePar = auteur;
        this.annuleLe = LocalDateTime.now();
    }

    public void initializeDefaults() {
        if (this.statut == null) this.statut = ContraventionStatus.EN_ATTENTE;
        if (this.montantPaye == null) this.montantPaye = BigDecimal.ZERO;
        // Saisie manuelle : le lien est MANUEL si un chauffeur est renseigné,
        // sinon la contravention reste à rattacher.
        if (this.statutRattachement == null) {
            this.statutRattachement = this.chauffeur != null
                    ? StatutRattachement.MANUEL
                    : StatutRattachement.A_RATTACHER;
        }
    }
}
