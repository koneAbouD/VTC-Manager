package com.tmk.vtcmanager.application.domain.payment;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Paiement Mobile Money d'une recette ou cotisation.
 *
 * L'argent va directement au compte marchand du gestionnaire (TMK n'encaisse
 * pas). Ce paiement pilote, en cas de succès, la création de l'encaissement
 * métier correspondant (via {@code encaissementId}, garant d'idempotence).
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Paiement {

    private Long id;
    /** Clé d'idempotence de l'initiation, générée côté serveur. */
    private String reference;
    private TypeCiblePaiement typeCible;
    private Long cibleId;
    private Long chauffeurId;
    private Long vehiculeId;
    private BigDecimal montant;
    private CanalPaiement canal;
    private String telephone;
    private StatutPaiement statut;
    /** Identifiant de la transaction côté agrégateur. */
    private String gatewayReference;
    /** URL de redirection éventuelle (paiement par lien). */
    private String paymentUrl;
    /** Encaissement métier créé au succès (null tant que non réglé). */
    private Long encaissementId;
    private String messageErreur;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    public boolean estRegle() {
        return encaissementId != null;
    }

    public boolean appartientA(Long chauffeurId) {
        return this.chauffeurId != null && this.chauffeurId.equals(chauffeurId);
    }
}
