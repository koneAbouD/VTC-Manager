package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.domain.coherence.ConflitChauffeurJour;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.TextesNotification;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.CoherenceGenerationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.stream.Collectors;

/**
 * Signale, sans rien bloquer, qu'une journée générée porte un chauffeur sur
 * plusieurs véhicules.
 *
 * <p>La génération parcourt les véhicules un par un et sert chaque conducteur
 * planifié : rien ne l'empêche de servir deux fois le même homme — le cas
 * arrive dès qu'un titulaire remplace un collègue absent sans être retiré de son
 * propre programme. Refuser reviendrait à ne pas créer une recette due, et
 * personne ne réclamerait l'argent. On crée donc, et on prévient.
 *
 * <p>La notification part vers les comptes de gestion, jamais vers les
 * chauffeurs : c'est une anomalie d'exploitation, pas un fait qui les concerne.
 * Une clé de regroupement par journée évite qu'une recette et quatre cotisations
 * générées d'affilée n'en fassent sonner cinq.
 */
@Slf4j
@RequiredArgsConstructor
public class SignalementCoherenceGenerationService {

    private static final List<String> ROLES_GESTION = List.of("ADMIN", "GESTIONNAIRE");
    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM/yyyy");

    private final CoherenceGenerationRepository coherenceRepository;
    private final com.tmk.vtcmanager.application.usecases.notification.CreerNotificationUseCase
            creerNotificationUseCase;
    private final KeycloakAdminPort keycloakAdminPort;

    /** À appeler après une génération. Silencieux quand la journée est saine. */
    public void controler(LocalDate date) {
        if (date == null) return;
        try {
            List<ConflitChauffeurJour> conflits =
                    coherenceRepository.chauffeursSurPlusieursVehicules(date, date);
            if (conflits.isEmpty()) return;

            log.warn("Génération du {} : {} chauffeur(s) sur plusieurs véhicules — {}",
                    date, conflits.size(), resume(conflits));

            String cle = "ANOMALIE_GENERATION:" + date;
            for (String destinataire : destinatairesGestion()) {
                creerNotificationUseCase.execute(Notification.builder()
                        .destinataireKeycloakId(destinataire)
                        .type(TypeNotification.ANOMALIE_GENERATION)
                        .titre(titre(conflits.size()))
                        .corps("La journée du " + date.format(JOUR) + " a produit des créances à"
                                + " vérifier.")
                        .detail(detail(date, conflits))
                        .cleGroupe(cle)
                        .build(), CUMUL);
            }
        } catch (Exception e) {
            // Le contrôle ne doit jamais faire échouer la génération : les lignes
            // sont créées, c'est l'essentiel.
            log.warn("Contrôle de cohérence du {} non abouti : {}", date, e.getMessage());
        }
    }

    private static String titre(int nombre) {
        return nombre == 1 ? "Chauffeur sur deux véhicules" : "Chauffeurs sur plusieurs véhicules";
    }

    /**
     * Le détail nomme les chauffeurs et leurs véhicules : sans cela, le
     * gestionnaire sait qu'il y a un problème mais pas où regarder.
     */
    private static String detail(LocalDate date, List<ConflitChauffeurJour> conflits) {
        return "Le " + date.format(JOUR) + ", " + resume(conflits)
                + ". Un chauffeur ne conduit qu'un véhicule par jour : vérifiez le programme de"
                + " travail, puis annulez la créance en trop ou réaffectez-la au bon chauffeur.";
    }

    private static String resume(List<ConflitChauffeurJour> conflits) {
        return conflits.stream()
                .map(c -> nom(c) + " porte des créances sur "
                        + String.join(" et ", c.immatriculations()))
                .collect(Collectors.joining(" ; "));
    }

    private static String nom(ConflitChauffeurJour conflit) {
        return conflit.chauffeurNom() == null || conflit.chauffeurNom().isBlank()
                ? "Le chauffeur n°" + conflit.chauffeurId() : conflit.chauffeurNom();
    }

    private static final TextesNotification CUMUL = new TextesNotification(
            "Créances à vérifier", "Plusieurs anomalies de génération sont à vérifier.");

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
}
