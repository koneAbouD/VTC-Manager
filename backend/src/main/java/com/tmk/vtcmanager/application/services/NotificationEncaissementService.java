package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.TextesNotification;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
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
 * Notifie les encaissements : accusé de réception au chauffeur qui a versé,
 * information aux comptes de gestion.
 *
 * <p>Côté chauffeur, l'accusé répond à un vrai besoin : il remet des espèces à
 * quelqu'un et n'a, sans cela, aucune trace immédiate que la somme a bien été
 * portée à son compte. Côté gestion, la notification signale l'entrée d'argent
 * à tous les responsables, celui qui l'a saisie compris — voir
 * {@link #destinatairesGestion()}.
 *
 * <p>Chaque message s'écrit en deux temps. Le <b>corps</b> part vers le
 * téléphone et s'affiche sur l'écran verrouillé, en dehors du code d'accès : il
 * reste donc sobre, sans montant ni nom — la raison est expliquée sur
 * {@link Notification}. Le <b>détail</b>, lui, ne sort que par l'API du centre
 * de notifications, derrière le jeton d'accès : il nomme le chauffeur, le
 * véhicule, les sommes, et dit s'il reste quelque chose à devoir.
 *
 * <p>Ce détail n'est pas le même selon qui lit. Le chauffeur sait qui il est et
 * quel véhicule il mène : ce qu'il veut vérifier, c'est son compte. Le
 * gestionnaire suit une flotte : sans le nom ni l'immatriculation, deux
 * encaissements successifs lui seraient indiscernables.
 *
 * <p>Rien de ce qui est fait ici ne doit empêcher un encaissement d'aboutir :
 * les destinataires de gestion se résolvent auprès de Keycloak, qui peut être
 * lent ou absent, et une notification manquée est sans commune mesure avec un
 * versement refusé au guichet. Toutes les erreurs sont donc absorbées.
 */
@Slf4j
@RequiredArgsConstructor
public class NotificationEncaissementService {

    /**
     * Rôles qui suivent les rentrées d'argent. Les deux, et pas seulement
     * GESTIONNAIRE : dans une petite structure, le compte qui supervise porte
     * souvent ADMIN et lui seul.
     */
    private static final List<String> ROLES_GESTION = List.of("ADMIN", "GESTIONNAIRE");

    private static final String ENTITE_LIGNE_RECETTE = "LIGNE_RECETTE";
    private static final String ENTITE_LIGNE_COTISATION = "LIGNE_COTISATION";

    /** Jour et mois suffisent à situer l'événement ; l'année n'apporte rien ici. */
    private static final DateTimeFormatter JOUR = DateTimeFormatter.ofPattern("dd/MM");

    private final CreerNotificationUseCase creerNotificationUseCase;
    private final ChauffeurRepository chauffeurRepository;
    private final KeycloakAdminPort keycloakAdminPort;

    public void recetteEncaissee(LigneRecette ligne, Encaissement encaissement) {
        if (ligne == null || encaissement == null) return;
        String jour = duJour(ligne.getDateRecette());
        BigDecimal montant = encaissement.getMontant();
        BigDecimal reste = reste(ligne.getMontantAttendu(), ligne.getMontantEncaisse(), montant);

        emettre(TypeNotification.RECETTE_ENCAISSEE, ENTITE_LIGNE_RECETTE, ligne.getId(),
                ligne.getChauffeurId(), encaissement.getDateEncaissement(),
                new Textes("Versement enregistré",
                        "Votre versement de recette" + jour + " a bien été enregistré.",
                        // Le chauffeur sait qui il est et quel véhicule il mène :
                        // ce qu'il veut vérifier, c'est le compte.
                        "Recette" + jour + " : " + francs(montant) + " reçus. " + etat(reste)),
                new Textes("Recette encaissée",
                        "Un encaissement de recette" + jour + " vient d'être saisi.",
                        // Le gestionnaire, lui, suit une flotte : sans le nom ni
                        // l'immatriculation, il ne sait pas de quoi on lui parle.
                        qui(ligne.getChauffeurNom(), ligne.getVehiculeImmatriculation())
                                + "recette" + jour + " : " + francs(montant) + ". " + etat(reste)));
    }

    public void cotisationEncaissee(LigneCotisation ligne, EncaissementCotisation encaissement) {
        if (ligne == null || encaissement == null) return;
        String jour = duJour(ligne.getDateCotisation());
        BigDecimal montant = encaissement.getMontant();
        BigDecimal reste = reste(ligne.getMontantDu(), ligne.getMontantEncaisse(), montant);
        String nom = ligne.getNomCotisation() == null ? "Cotisation" : ligne.getNomCotisation();

        emettre(TypeNotification.COTISATION_ENCAISSEE, ENTITE_LIGNE_COTISATION, ligne.getId(),
                ligne.getChauffeurId(), encaissement.getDateEncaissement(),
                new Textes("Cotisation enregistrée",
                        "Votre cotisation" + jour + " a bien été enregistrée.",
                        nom + jour + " : " + francs(montant) + " reçus. " + etat(reste)),
                new Textes("Cotisation encaissée",
                        "Un encaissement de cotisation" + jour + " vient d'être saisi.",
                        qui(ligne.getChauffeurNom(), ligne.getVehiculeImmatriculation())
                                + nom + jour + " : " + francs(montant) + ". " + etat(reste)));
    }

    /**
     * Ce que lit une population de destinataires : le titre et le corps partent
     * vers le téléphone, le détail reste dans l'application.
     */
    private record Textes(String titre, String corps, String detail) {}

    private void emettre(TypeNotification type, String entiteType, Long entiteId, Long chauffeurId,
                         LocalDate dateEncaissement, Textes pourChauffeur, Textes pourGestion) {
        try {
            // Un versement réparti entre recette et cotisation arrive en deux
            // requêtes : la clé les rassemble pour n'en faire sonner qu'une.
            String cle = cleGroupe(chauffeurId, dateEncaissement);

            destinataireChauffeur(chauffeurId).ifPresent(sub ->
                    creer(sub, type, entiteType, entiteId, cle, pourChauffeur, CUMUL_CHAUFFEUR));

            for (String sub : destinatairesGestion()) {
                creer(sub, type, entiteType, entiteId, cle, pourGestion, CUMUL_GESTION);
            }
        } catch (Exception e) {
            // L'encaissement, lui, est acquis : il ne sera pas défait pour un
            // message qui n'a pas pu partir.
            log.warn("Encaissement {} {} non notifié : {}", entiteType, entiteId, e.getMessage());
        }
    }

    /** « KOUAMÉ Jean — AB-123-CD · », ou rien si la ligne ne porte pas ces libellés. */
    private static String qui(String chauffeur, String immatriculation) {
        String gauche = chauffeur == null || chauffeur.isBlank() ? null : chauffeur.trim();
        String droite = immatriculation == null || immatriculation.isBlank()
                ? null : immatriculation.trim();

        if (gauche == null && droite == null) return "";
        if (gauche == null) return droite + " · ";
        if (droite == null) return gauche + " · ";
        return gauche + " — " + droite + " · ";
    }

    /** Reste dû après cet encaissement. Nul quand la ligne n'a pas de plafond. */
    private static BigDecimal reste(BigDecimal attendu, BigDecimal dejaEncaisse, BigDecimal montant) {
        if (attendu == null) return null;
        BigDecimal cumul = (dejaEncaisse == null ? BigDecimal.ZERO : dejaEncaisse)
                .add(montant == null ? BigDecimal.ZERO : montant);
        return attendu.subtract(cumul);
    }

    /**
     * Ce qu'il reste à devoir, en clair. C'est l'information que l'on cherche
     * vraiment : le versement est-il complet ?
     */
    private static String etat(BigDecimal reste) {
        if (reste == null) return "Montant libre.";
        if (reste.signum() <= 0) return "Solde à jour.";
        return "Reste " + francs(reste) + ".";
    }

    /** « 15 000 FCFA », séparateur de milliers à la française. */
    private static String francs(BigDecimal montant) {
        if (montant == null) return "0 FCFA";
        DecimalFormat format = new DecimalFormat("#,##0", new DecimalFormatSymbols(Locale.FRANCE));
        return format.format(montant) + " FCFA";
    }

    /**
     * Ce qui se lit à la place quand un second encaissement du même geste
     * survient. Sans date ni nature : le message couvre désormais une recette et
     * une cotisation, parfois de journées de travail différentes.
     */
    private static final TextesNotification CUMUL_CHAUFFEUR = new TextesNotification(
            "Versements enregistrés", "Vos versements ont bien été enregistrés.");

    private static final TextesNotification CUMUL_GESTION = new TextesNotification(
            "Encaissements", "Plusieurs encaissements viennent d'être saisis.");

    /**
     * Le geste, c'est ce qu'un chauffeur a versé un jour donné — pas la ligne
     * qu'on solde avec. Nulle si l'un des deux manque : sans clé, chaque
     * notification vit sa vie, ce qui reste le comportement sûr.
     */
    private static String cleGroupe(Long chauffeurId, LocalDate dateEncaissement) {
        if (chauffeurId == null || dateEncaissement == null) return null;
        return "ENCAISSEMENT:" + chauffeurId + ":" + dateEncaissement;
    }

    /**
     * Le chauffeur n'est joignable que s'il a un compte : ceux qui n'ont jamais
     * ouvert l'application chauffeur n'ont pas de {@code sub} Keycloak, et il
     * n'y a alors personne à prévenir.
     */
    private Optional<String> destinataireChauffeur(Long chauffeurId) {
        if (chauffeurId == null) return Optional.empty();
        return chauffeurRepository.findById(chauffeurId)
                .map(Chauffeur::getKeycloakUserId)
                .filter(sub -> !sub.isBlank());
    }

    /**
     * Tous les comptes de gestion, <b>y compris celui qui vient de saisir</b>.
     *
     * <p>L'écarter partait d'une bonne intention — on n'apprend rien de son
     * propre geste — mais dans une exploitation où un seul gestionnaire tient
     * la caisse, cela revenait à ne notifier personne : les autres comptes
     * n'ont pas d'appareil enregistré. Recevoir l'écho de sa propre écriture
     * est le prix d'une règle qui se vérifie, et l'interrupteur des réglages
     * reste là pour qui n'en veut pas.
     */
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
            // Keycloak indisponible : le chauffeur, lui, a déjà été prévenu.
            log.warn("Destinataires de gestion introuvables : {}", e.getMessage());
            return List.of();
        }
    }

    private void creer(String destinataire, TypeNotification type, String entiteType, Long entiteId,
                       String cleGroupe, Textes textes, TextesNotification siDejaNotifie) {
        creerNotificationUseCase.execute(Notification.builder()
                .destinataireKeycloakId(destinataire)
                .type(type)
                .titre(textes.titre())
                .corps(textes.corps())
                .detail(textes.detail())
                .entiteType(entiteType)
                .entiteId(entiteId)
                .cleGroupe(cleGroupe)
                .build(), siDejaNotifie);
    }

    private static String duJour(LocalDate date) {
        return date == null ? "" : " du " + date.format(JOUR);
    }
}
