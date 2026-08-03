package com.tmk.vtcmanager.application.domain.notification;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * Une notification adressée à un compte : à la fois le message poussé sur son
 * téléphone et la ligne consultable dans le centre de notifications.
 *
 * <p>Le texte reste sobre à dessein. Une notification s'affiche sur l'écran
 * verrouillé, en dehors du code d'accès qui protège l'application : elle
 * annonce qu'il s'est passé quelque chose, sans exposer les montants, les noms
 * ni les immatriculations. Le détail se lit dans l'application.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Notification {

    private Long id;

    /** Claim {@code sub} Keycloak du destinataire. */
    private String destinataireKeycloakId;

    private TypeNotification type;
    private String titre;
    private String corps;

    /**
     * Ce que le corps ne peut pas dire.
     *
     * <p>Le corps s'affiche sur l'écran verrouillé et reste donc muet ; ce
     * détail-ci ne sort que par l'API du centre de notifications, derrière le
     * jeton d'accès et le code de l'application. Il peut nommer le chauffeur,
     * le véhicule et les montants — c'est là que la notification devient
     * réellement utile à qui tient la caisse.
     */
    private String detail;

    /** Type de l'objet visé par le lien profond (ex. {@code LIGNE_PENALITE}). */
    private String entiteType;

    /** Identifiant de cet objet. */
    private Long entiteId;

    /**
     * Identifie le geste à l'origine de la notification (ex.
     * {@code ENCAISSEMENT:9:2026-08-03}), pour que deux faits qui n'en forment
     * qu'un pour l'utilisateur ne fassent pas vibrer deux fois son téléphone.
     * Nulle quand la notification porte un fait unique.
     */
    private String cleGroupe;

    private boolean lue;
    private LocalDateTime lueLe;
    private LocalDateTime envoyeeLe;
    private LocalDateTime creeLe;

    public void validate() {
        if (destinataireKeycloakId == null || destinataireKeycloakId.isBlank()) {
            throw new IllegalArgumentException("Le destinataire de la notification est obligatoire.");
        }
        if (type == null) {
            throw new IllegalArgumentException("Le type de notification est obligatoire.");
        }
        if (titre == null || titre.isBlank()) {
            throw new IllegalArgumentException("Le titre de la notification est obligatoire.");
        }
        if (corps == null || corps.isBlank()) {
            throw new IllegalArgumentException("Le corps de la notification est obligatoire.");
        }
    }

    /**
     * Charge utile technique accompagnant le message, lue par l'application pour
     * ouvrir le bon écran. Uniquement des identifiants : rien qui n'ait sa place
     * sur un écran verrouillé.
     */
    public Map<String, String> donneesPush() {
        Map<String, String> donnees = new HashMap<>();
        donnees.put("type", type.name());
        if (id != null) {
            donnees.put("notificationId", String.valueOf(id));
        }
        if (entiteType != null) {
            donnees.put("entiteType", entiteType);
        }
        if (entiteId != null) {
            donnees.put("entiteId", String.valueOf(entiteId));
        }
        return donnees;
    }
}
