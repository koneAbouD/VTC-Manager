package com.tmk.vtcmanager.application.domain.contravention;

import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.vehicule.Vehicule;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
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
    private LocalDate datePaiement;
    private Chauffeur chauffeur;
    private Vehicule vehicule;

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
     * Marque la contravention comme reversée (par ex. l'entreprise reverse à l'État).
     */
    public void reverser() {
        this.statut = ContraventionStatus.REVERSE;
        this.datePaiement = LocalDate.now();
    }

    public void initializeDefaults() {
        if (this.statut == null) this.statut = ContraventionStatus.EN_ATTENTE;
        if (this.montantPaye == null) this.montantPaye = BigDecimal.ZERO;
    }
}
