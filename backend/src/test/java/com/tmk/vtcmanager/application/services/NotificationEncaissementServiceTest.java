package com.tmk.vtcmanager.application.services;

import com.tmk.vtcmanager.application.domain.auth.UserInfo;
import com.tmk.vtcmanager.application.domain.chauffeur.Chauffeur;
import com.tmk.vtcmanager.application.domain.cotisation.EncaissementCotisation;
import com.tmk.vtcmanager.application.domain.cotisation.LigneCotisation;
import com.tmk.vtcmanager.application.domain.notification.Notification;
import com.tmk.vtcmanager.application.domain.notification.TypeNotification;
import com.tmk.vtcmanager.application.domain.recette.Encaissement;
import com.tmk.vtcmanager.application.domain.recette.LigneRecette;
import com.tmk.vtcmanager.application.ports.auth.KeycloakAdminPort;
import com.tmk.vtcmanager.application.ports.persistence.ChauffeurRepository;
import com.tmk.vtcmanager.application.usecases.notification.CreerNotificationUseCase;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class NotificationEncaissementServiceTest {

    private static final String SUB_CHAUFFEUR = "sub-chauffeur";
    private static final String SUB_PATRON = "sub-patron";
    private static final String SUB_AUTEUR = "sub-auteur";

    /** Jour du versement : ce qui fait le geste, et donc la clé de regroupement. */
    private static final LocalDate VERSE_LE = LocalDate.of(2026, 8, 3);

    private static final BigDecimal MONTANT_VERSE = new BigDecimal("15000");

    private CreerNotificationUseCase creerNotificationUseCase;
    private ChauffeurRepository chauffeurRepository;
    private KeycloakAdminPort keycloakAdminPort;
    private NotificationEncaissementService service;

    @BeforeEach
    void setUp() {
        creerNotificationUseCase = mock(CreerNotificationUseCase.class);
        chauffeurRepository = mock(ChauffeurRepository.class);
        keycloakAdminPort = mock(KeycloakAdminPort.class);
        service = new NotificationEncaissementService(
                creerNotificationUseCase, chauffeurRepository, keycloakAdminPort);

        when(keycloakAdminPort.getUsersByRole(anyString())).thenReturn(List.of());
    }

    @Test
    void previent_le_chauffeur_qui_a_verse() {
        donneUnChauffeurAvecCompte(9L);

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        Notification envoyee = capturerUnique();
        assertThat(envoyee.getDestinataireKeycloakId()).isEqualTo(SUB_CHAUFFEUR);
        assertThat(envoyee.getType()).isEqualTo(TypeNotification.RECETTE_ENCAISSEE);
        assertThat(envoyee.getEntiteType()).isEqualTo("LIGNE_RECETTE");
        assertThat(envoyee.getEntiteId()).isEqualTo(42L);
    }

    @Test
    void ne_nomme_ni_montant_ni_personne_dans_le_corps() {
        donneUnChauffeurAvecCompte(9L);

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        // Le corps part vers FCM et s'affiche sur l'écran verrouillé, hors du
        // code d'accès : il ne doit rien porter de nominatif ni de chiffré.
        Notification envoyee = capturerUnique();
        assertThat(envoyee.getCorps())
                .contains("03/08")
                .doesNotContain("15", "KOUAME", "AB-123-CD");
    }

    @Test
    void dit_au_chauffeur_ce_qu_il_a_verse_et_ce_qu_il_doit_encore() {
        donneUnChauffeurAvecCompte(9L);

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        // Le chauffeur sait qui il est : son détail va droit aux chiffres.
        assertThat(capturerUnique().getDetail())
                .contains("15")
                .contains("Reste")
                .doesNotContain("KOUAME");
    }

    @Test
    void nomme_le_chauffeur_et_le_vehicule_pour_la_gestion() {
        donneUnChauffeurSansCompte(9L);
        when(keycloakAdminPort.getUsersByRole("ADMIN"))
                .thenReturn(List.of(utilisateur(SUB_PATRON, "patron")));

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        // Sans le nom ni l'immatriculation, deux encaissements successifs
        // seraient indiscernables dans le centre de notifications.
        Notification envoyee = capturerUnique();
        assertThat(envoyee.getDetail())
                .contains("KOUAME Jean")
                .contains("AB-123-CD")
                .contains("15");
        assertThat(envoyee.getCorps()).doesNotContain("KOUAME", "AB-123-CD");
    }

    @Test
    void annonce_un_solde_a_jour_quand_la_ligne_est_soldee() {
        donneUnChauffeurAvecCompte(9L);
        LigneRecette ligne = ligneRecette(9L, LocalDate.of(2026, 8, 3));
        ligne.setMontantEncaisse(new BigDecimal("5000"));

        service.recetteEncaissee(ligne, versement());

        assertThat(capturerUnique().getDetail()).contains("Solde à jour");
    }

    @Test
    void ne_promet_pas_de_reste_sur_une_recette_a_montant_libre() {
        donneUnChauffeurAvecCompte(9L);
        LigneRecette ligne = ligneRecette(9L, LocalDate.of(2026, 8, 3));
        ligne.setMontantAttendu(null);

        service.recetteEncaissee(ligne, versement());

        assertThat(capturerUnique().getDetail()).contains("Montant libre");
    }

    @Test
    void previent_les_comptes_de_gestion_y_compris_celui_qui_a_saisi() {
        donneUnChauffeurSansCompte(9L);
        when(keycloakAdminPort.getUsersByRole("ADMIN")).thenReturn(List.of(
                utilisateur(SUB_PATRON, "patron"),
                utilisateur(SUB_AUTEUR, "akone")));

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        // Écarter l'auteur revenait, dans une exploitation à un seul
        // gestionnaire équipé, à ne prévenir personne du tout.
        ArgumentCaptor<Notification> capteur = ArgumentCaptor.forClass(Notification.class);
        verify(creerNotificationUseCase, times(2)).execute(capteur.capture(), any());
        assertThat(capteur.getAllValues())
                .extracting(Notification::getDestinataireKeycloakId)
                .containsExactly(SUB_PATRON, SUB_AUTEUR);
    }

    @Test
    void ne_previent_qu_une_fois_un_compte_qui_porte_les_deux_roles() {
        donneUnChauffeurSansCompte(9L);
        when(keycloakAdminPort.getUsersByRole("ADMIN"))
                .thenReturn(List.of(utilisateur(SUB_PATRON, "patron")));
        when(keycloakAdminPort.getUsersByRole("GESTIONNAIRE"))
                .thenReturn(List.of(utilisateur(SUB_PATRON, "patron")));

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        assertThat(capturerUnique().getDestinataireKeycloakId()).isEqualTo(SUB_PATRON);
    }

    @Test
    void ignore_un_compte_desactive() {
        donneUnChauffeurSansCompte(9L);
        UserInfo parti = utilisateur(SUB_PATRON, "patron");
        parti.setEnabled(false);
        when(keycloakAdminPort.getUsersByRole("GESTIONNAIRE")).thenReturn(List.of(parti));

        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement());

        verify(creerNotificationUseCase, never()).execute(any(), any());
    }

    @Test
    void ne_notifie_pas_un_chauffeur_sans_compte() {
        donneUnChauffeurSansCompte(9L);

        service.cotisationEncaissee(ligneCotisation(9L, LocalDate.of(2026, 8, 3)), versementCotisation());

        verify(creerNotificationUseCase, never()).execute(any(), any());
    }

    @Test
    void une_panne_keycloak_ne_remonte_pas_a_l_encaissement() {
        donneUnChauffeurAvecCompte(9L);
        when(keycloakAdminPort.getUsersByRole(anyString()))
                .thenThrow(new IllegalStateException("Keycloak injoignable"));

        assertThatCode(() -> service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 3)), versement()))
                .doesNotThrowAnyException();

        // Le chauffeur, lui, a bien été prévenu avant la panne.
        assertThat(capturerUnique().getDestinataireKeycloakId()).isEqualTo(SUB_CHAUFFEUR);
    }

    @Test
    void recette_et_cotisation_du_meme_versement_partagent_la_cle_de_groupe() {
        donneUnChauffeurAvecCompte(9L);

        // L'encaissement rapide : deux requêtes, un seul geste. Les lignes
        // soldées peuvent porter des dates différentes, c'est le jour du
        // versement qui les rassemble.
        service.recetteEncaissee(ligneRecette(9L, LocalDate.of(2026, 8, 2)), versement());
        service.cotisationEncaissee(ligneCotisation(9L, LocalDate.of(2026, 7, 30)), versementCotisation());

        ArgumentCaptor<Notification> capteur = ArgumentCaptor.forClass(Notification.class);
        verify(creerNotificationUseCase, times(2)).execute(capteur.capture(), any());
        assertThat(capteur.getAllValues())
                .extracting(Notification::getCleGroupe)
                .containsExactly("ENCAISSEMENT:9:2026-08-03", "ENCAISSEMENT:9:2026-08-03");
    }

    @Test
    void la_cotisation_porte_son_propre_type() {
        donneUnChauffeurAvecCompte(9L);

        service.cotisationEncaissee(ligneCotisation(9L, LocalDate.of(2026, 8, 3)), versementCotisation());

        Notification envoyee = capturerUnique();
        assertThat(envoyee.getType()).isEqualTo(TypeNotification.COTISATION_ENCAISSEE);
        assertThat(envoyee.getEntiteType()).isEqualTo("LIGNE_COTISATION");
    }

    // ── Fixtures ──

    private void donneUnChauffeurAvecCompte(Long id) {
        Chauffeur chauffeur = new Chauffeur();
        chauffeur.setId(id);
        chauffeur.setKeycloakUserId(SUB_CHAUFFEUR);
        when(chauffeurRepository.findById(id)).thenReturn(Optional.of(chauffeur));
    }

    private void donneUnChauffeurSansCompte(Long id) {
        Chauffeur chauffeur = new Chauffeur();
        chauffeur.setId(id);
        when(chauffeurRepository.findById(id)).thenReturn(Optional.of(chauffeur));
    }

    /** Recette de 20 000 attendus, rien de versé jusqu'ici. */
    private static LigneRecette ligneRecette(Long chauffeurId, LocalDate date) {
        LigneRecette ligne = new LigneRecette();
        ligne.setId(42L);
        ligne.setChauffeurId(chauffeurId);
        ligne.setChauffeurNom("KOUAME Jean");
        ligne.setVehiculeImmatriculation("AB-123-CD");
        ligne.setDateRecette(date);
        ligne.setMontantAttendu(new BigDecimal("20000"));
        ligne.setMontantEncaisse(BigDecimal.ZERO);
        return ligne;
    }

    private static LigneCotisation ligneCotisation(Long chauffeurId, LocalDate date) {
        LigneCotisation ligne = new LigneCotisation();
        ligne.setId(42L);
        ligne.setChauffeurId(chauffeurId);
        ligne.setChauffeurNom("KOUAME Jean");
        ligne.setVehiculeImmatriculation("AB-123-CD");
        ligne.setDateCotisation(date);
        ligne.setNomCotisation("Assurance");
        ligne.setMontantDu(new BigDecimal("2000"));
        ligne.setMontantEncaisse(BigDecimal.ZERO);
        return ligne;
    }

    private static Encaissement versement() {
        return Encaissement.builder()
                .montant(MONTANT_VERSE)
                .dateEncaissement(VERSE_LE)
                .build();
    }

    private static EncaissementCotisation versementCotisation() {
        return EncaissementCotisation.builder()
                .montant(new BigDecimal("2000"))
                .dateEncaissement(VERSE_LE)
                .build();
    }

    private static UserInfo utilisateur(String id, String username) {
        return UserInfo.builder().id(id).username(username).enabled(true).build();
    }

    private Notification capturerUnique() {
        ArgumentCaptor<Notification> capteur = ArgumentCaptor.forClass(Notification.class);
        verify(creerNotificationUseCase).execute(capteur.capture(), any());
        return capteur.getValue();
    }
}
