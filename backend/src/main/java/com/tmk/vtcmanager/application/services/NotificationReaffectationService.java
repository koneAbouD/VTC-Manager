package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.finance.TypeDocumentCreance;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.usecases.notification.CreerNotificationUseCase;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.math.BigDecimal;
import java.text.DecimalFormat;
import java.text.DecimalFormatSymbols;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

/**
 * Prévient qui doit l'être quand une créance change de débiteur.
 *
 * <p>Les deux chauffeurs, et pas seulement le nouveau : celui qu'on décharge a
 * reçu un accusé nominatif au moment du versement, et verrait autrement la
 * somme disparaître de son compte sans explication. Chacun reçoit donc sa
 * propre lecture du même fait — retrait pour l'un, imputation pour l'autre —
 * plus l'information aux comptes de gestion, comme pour un encaissement.
 *
 * <p>Même discipline que {@link NotificationEncaissementService} : le corps
 * part sur l'écran verrouillé et reste sobre, le détail ne sort que derrière le
 * jeton ; et rien de ce qui se passe ici ne peut faire échouer la réaffectation,
 * qui est déjà écrite.
 */
@Slf4j
@RequiredArgsConstructor
public class NotificationReaffectationService {

    private static final List<String> ROLES_GESTION = List.of("ADMIN", "GESTIONNAIRE");
    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM");

    private final CreerNotificationUseCase creerNotificationUseCase;
    private final ChauffeurRepository chauffeurRepository;
    private final KeycloakAdminPort keycloakAdminPort;

    /**
     * @param document      RECETTE ou COTISATION — nomme la créance déplacée
     * @param montantRestant ce qui reste dû après le déplacement, ou null si la
     *                       ligne n'a pas de plafond chiffrable
     */
    public void ligneReaffectee(TypeDocumentCreance document, Long ligneId, LocalDate date,
                                String immatriculation, BigDecimal montantRestant,
                                Long ancienChauffeurId, String ancienNom,
                                Long nouveauChauffeurId, String nouveauNom) {
        try {
            String quoi = document == TypeDocumentCreance.COTISATION ? "cotisation" : "recette";
            String entite = document == TypeDocumentCreance.COTISATION
                    ? "LIGNE_COTISATION" : "LIGNE_RECETTE";
            String jour = date == null ? "" : " du " + date.format(JOUR);
            String reste = montantRestant == null || montantRestant.signum() <= 0
                    ? "Rien ne reste à devoir." : "Reste " + francs(montantRestant) + ".";

            destinataire(ancienChauffeurId).ifPresent(sub -> creer(sub, entite, ligneId,
                    "Créance retirée de votre compte",
                    "Une " + quoi + jour + " n'est plus à votre charge.",
                    "La " + quoi + jour + " sur " + vehicule(immatriculation)
                            + " a été portée au compte d'un autre chauffeur. Elle ne figure plus"
                            + " parmi vos créances."));

            destinataire(nouveauChauffeurId).ifPresent(sub -> creer(sub, entite, ligneId,
                    "Créance portée à votre compte",
                    "Une " + quoi + jour + " vient d'être portée à votre compte.",
                    "La " + quoi + jour + " sur " + vehicule(immatriculation)
                            + " est désormais à votre charge. " + reste));

            for (String sub : destinatairesGestion()) {
                creer(sub, entite, ligneId,
                        "Créance réaffectée",
                        "Une " + quoi + jour + " a changé de chauffeur.",
                        vehicule(immatriculation) + " · " + quoi + jour + " : "
                                + nom(ancienNom) + " → " + nom(nouveauNom) + ". " + reste);
            }
        } catch (Exception e) {
            // La réaffectation est acquise : elle ne sera pas défaite pour un
            // message qui n'a pas pu partir.
            log.warn("Réaffectation {} {} non notifiée : {}", document, ligneId, e.getMessage());
        }
    }

    private void creer(String destinataire, String entiteType, Long entiteId,
                       String titre, String corps, String detail) {
        creerNotificationUseCase.execute(Notification.builder()
                .destinataireKeycloakId(destinataire)
                .type(TypeNotification.LIGNE_REAFFECTEE)
                .titre(titre)
                .corps(corps)
                .detail(detail)
                .entiteType(entiteType)
                .entiteId(entiteId)
                .build());
    }

    /** Sans compte sur l'application chauffeur, il n'y a personne à prévenir. */
    private Optional<String> destinataire(Long chauffeurId) {
        if (chauffeurId == null) return Optional.empty();
        return chauffeurRepository.findById(chauffeurId)
                .map(Chauffeur::getKeycloakUserId)
                .filter(sub -> !sub.isBlank());
    }

    private List<String> destinatairesGestion() {
        try {
            return ROLES_GESTION.stream()
                    .flatMap(role -> keycloakAdminPort.getUsersByRole(role).stream())
                    .filter(UserInfo::isEnabled)
                    .filter(u -> u.getId() != null && !u.getId().isBlank())
                    .map(UserInfo::getId)
                    .distinct()
                    .toList();
        } catch (Exception e) {
            log.warn("Destinataires de gestion introuvables : {}", e.getMessage());
            return List.of();
        }
    }

    private static String vehicule(String immatriculation) {
        return immatriculation == null || immatriculation.isBlank()
                ? "le véhicule" : immatriculation.trim();
    }

    private static String nom(String nom) {
        return nom == null || nom.isBlank() ? "chauffeur inconnu" : nom.trim();
    }

    private static String francs(BigDecimal montant) {
        DecimalFormat format = new DecimalFormat("#,##0", new DecimalFormatSymbols(Locale.FRANCE));
        return format.format(montant) + " FCFA";
    }
}
