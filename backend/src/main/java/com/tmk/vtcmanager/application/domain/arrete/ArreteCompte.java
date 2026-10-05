package com.tmk.vtcmanager.application.domain.arrete;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

/**
 * Arrêté de compte : compensation des dettes et créances réciproques d'un
 * périmètre (chauffeur ou véhicule) sur une période libre, figée à une date.
 * Fait comptable immuable — annulable seulement avec motif.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ArreteCompte {

    private Long id;
    private PerimetreArrete perimetre;
    private Long perimetreId;
    /** Libellé du périmètre (nom chauffeur ou immatriculation), transient. */
    private String perimetreLibelle;
    private LocalDate periodeDebut;
    private LocalDate periodeFin;
    private LocalDate dateArrete;
    private String reference;
    private StatutArrete statut;
    private String motifAnnulation;

    /**
     * Solde de compte courant du périmètre après cet arrêté (transient, calculé
     * à la lecture) : &gt; 0 = reste à restituer, &lt; 0 = reste dû, 0 = soldé.
     */
    private BigDecimal resteNet;

    @Builder.Default
    private List<LigneArrete> lignes = new ArrayList<>();
    @Builder.Default
    private List<ReglementArrete> reglements = new ArrayList<>();
    /** Créances laissées ouvertes, datées jusqu'à la fin de période : le détail du reste dû. */
    @Builder.Default
    private List<DetteRestanteArrete> dettesRestantes = new ArrayList<>();

    /**
     * Premier jour du mois de début : un arrêté couvre des mois entiers. Les
     * arrêtés enregistrés avant cette règle portent des bornes resserrées sur
     * la première cotisation ; on les élargit à la lecture plutôt que de
     * réécrire l'historique.
     */
    public LocalDate debutMois() {
        return periodeDebut != null ? periodeDebut.withDayOfMonth(1) : null;
    }

    /** Dernier jour du mois de fin (voir {@link #debutMois()}). */
    public LocalDate finMois() {
        return periodeFin != null ? periodeFin.withDayOfMonth(periodeFin.lengthOfMonth()) : null;
    }

    /** Total restitué (somme des nets positifs des règlements). */
    public BigDecimal totalRestitue() {
        return reglements.stream()
                .map(ReglementArrete::getMontantNet)
                .filter(m -> m != null && m.signum() > 0)
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }
}
